defmodule Core.Services.Shell.Demo do
  use Core.Services.Base
  require Logger
  alias Core.PubSub
  alias Core.Schema.{User, DemoProject, CloudShell}
  alias Core.Services.{Locks, Users, Upgrades, Repositories, Dns}
  alias GoogleApi.CloudResourceManager.V3.Api.{Projects, Operations}
  alias GoogleApi.CloudResourceManager.V3.Model.{Project, Operation, SetIamPolicyRequest, MoveProjectRequest}
  alias GoogleApi.CloudResourceManager.V3.Connection, as: ProjectsConnection
  alias GoogleApi.IAM.V1.Connection, as: IAMConnection
  alias GoogleApi.IAM.V1.Api.Projects, as: IAMProjects
  alias GoogleApi.IAM.V1.Model.{CreateServiceAccountRequest, Binding, ServiceAccountKey}
  alias GoogleApi.CloudBilling.V1.Connection, as: BillingConnection
  alias GoogleApi.CloudBilling.V1.Api.Projects, as: BillingProjects
  alias GoogleApi.CloudBilling.V1.Api.BillingAccounts
  alias GoogleApi.ServiceUsage.V1.Api.Services, as: ServiceUsage
  alias GoogleApi.ServiceUsage.V1.Api.Operations, as: SvcsOperations
  alias GoogleApi.ServiceUsage.V1.Connection, as: SvcsConnection
  alias GoogleApi.ServiceUsage.V1.Model.{BatchEnableServicesRequest}
  alias GoogleApi.ServiceUsage.V1.Model.Operation, as: SvcOperation


  @type error :: {:error, term}
  @type demo_resp :: {:ok, DemoProject.t} | error

  @lock "demo-projects"
  @max_count 3

  @spec max_demo_count :: integer
  def max_demo_count, do: @max_count

  @spec has_demo?(binary) :: boolean
  def has_demo?(user_id) do
    DemoProject.for_user(user_id)
    |> Core.Repo.exists?()
  end

  @spec get_demo_project(binary) :: DemoProject.t | nil
  def get_demo_project(id), do: Core.Repo.get(DemoProject, id)

  @spec get_by_user_id(binary) :: DemoProject.t | nil
  def get_by_user_id(id), do: Core.Repo.get_by(DemoProject, user_id: id)

  @spec get_shell(binary) :: CloudShell.t | nil
  def get_shell(id), do: Core.Repo.get_by(CloudShell, demo_id: id)

  @doc """
  Returns at most `limit` demo projects for deletion.  This operation should be atomic, and will mark each project with
  a heartbeat ts to track status in the deletion pipeline.
  """
  @spec poll(integer) :: {:ok, [DemoProject.t]} | error
  def poll(limit) do
    owner = Ecto.UUID.generate()

    start_transaction()
    |> add_operation(:lock, fn _ -> Locks.acquire(@lock, owner) end)
    |> add_operation(:fetch, fn _ ->
      DemoProject.expired()
      |> DemoProject.dequeue(limit)
      |> Core.Repo.all()
      |> ok()
    end)
    |> add_operation(:mark, fn %{fetch: projects} ->
      projects
      |> Enum.map(& &1.id)
      |> DemoProject.for_ids()
      |> DemoProject.selected()
      |> Core.Repo.update_all(set: [heartbeat: Timex.now()])
      |> elem(1)
      |> ok()
    end)
    |> add_operation(:release, fn _ -> Locks.release(@lock) end)
    |> execute(extract: :mark)
  end

  @doc """
  Creates a new demo project.  GCP project creation is a long-running operation, so you'll
  need to poll the project afterwards.
  """
  @spec create_demo_project(User.t) :: {:ok, DemoProject.t} | error
  def create_demo_project(%User{id: id} = user) do
    case Core.Repo.get_by(DemoProject, user_id: id) do
      %DemoProject{} = p -> {:ok, p}
      _ -> do_create_demo_project(user)
    end
  end

  def do_create_demo_project(%User{demo_count: c}) when c >= @max_count,
    do: {:error, "You're only allowed to create #{@max_count} demo projects"}
  def do_create_demo_project(%User{id: user_id, demo_count: count} = user) do
    projs = projects_conn()
    start_transaction()
    |> add_operation(:db, fn _ ->
      %DemoProject{user_id: user_id, state: :created}
      |> DemoProject.changeset(%{project_id: project_id(user)})
      |> Core.Repo.insert()
    end)
    |> add_operation(:project, fn %{db: %{project_id: proj_id}} ->
      Projects.cloudresourcemanager_projects_create(projs, body: %Project{
        projectId: proj_id,
        displayName: proj_id,
        parent: "organizations/#{org_id()}"
      })
    end)
    |> add_operation(:final, fn %{db: demo, project: %{name: "operations/" <> op_id}} ->
      DemoProject.changeset(demo, %{ready: false, operation_id: op_id})
      |> Core.Repo.update()
    end)
    |> add_operation(:user, fn _ ->
      Users.update_user(%{demo_count: (count || 0) + 1}, user)
    end)
    |> execute(extract: :final)
    |> notify(:create)
  end

  @doc """
  Transfers a demo project to another organization
  """
  @spec transfer_demo_project(binary, User.t) :: demo_resp
  def transfer_demo_project(org_id, %User{id: user_id}) do
    demo = get_by_user_id(user_id)
    projs = projects_conn()

    start_transaction()
    |> add_operation(:move, fn _ ->
      Projects.cloudresourcemanager_projects_move(projs, demo.project_id, body: %MoveProjectRequest{
        destinationParent: "organizations/#{org_id}"
      })
    end)
    |> add_operation(:shell, fn _ ->
      with %{} = shell <- Core.Services.Shell.get_shell(user_id) do
        Ecto.Changeset.change(shell, %{demo_id: nil})
        |> Core.Repo.update()
      else
        _ -> {:ok, nil}
      end
    end)
    |> add_operation(:delete, fn _ -> Core.Repo.delete(demo) end)
    |> execute(extract: :delete)
  end

  @doc """
  Deletes the demo project and its associated gcp project
  """
  @spec delete_demo_project(DemoProject.t) :: {:ok, DemoProject.t} | error
  def delete_demo_project(%DemoProject{project_id: proj_id} = proj) do
    proj = Core.Repo.preload(proj, [:user])
    start_transaction()
    |> add_operation(:proj, fn _ ->
      projects_conn()
      |> Projects.cloudresourcemanager_projects_delete(proj_id)
      |> case do
        {:ok, _} = ok -> ok
        {:error, %Tesla.Env{status: 404}} -> {:ok, :not_found}
        {:error, %Tesla.Env{status: 403}} -> {:ok, :no_perms} # seems to also happen when not found
        err -> handle_error(err)
      end
    end)
    |> add_operation(:cluster, fn _ ->
      with %{provider: p, workspace: %{cluster: c, subdomain: d}} <- get_shell(proj.id),
            {:ok, _} <- Dns.empty_domain(d, proj.user) do
        {:ok, true}
      else
        _ -> {:ok, false}
      end
    end)
    |> add_operation(:db, fn _ -> Core.Repo.delete(proj) end)
    |> add_operation(:maybe_reset, fn _ ->
      case Upgrades.queue_count(proj.user_id) do
        n when n <= 1 -> Repositories.reset_installations(proj.user)
        _ -> {:ok, nil}
      end
    end)
    |> execute(extract: :db)
    |> notify(:delete)
  end

  defp handle_error({:error, %Tesla.Env{body: body}} = err) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => "Project not active"}}} ->
        Logger.info "inactive project, can delete"
        {:ok, :inactive}
      {:ok, body} ->
        Logger.error "unrecognized error body: #{inspect(body)}"
        err
      _ -> err
    end
  end
  defp handle_error(err), do: err

  @doc """
  Deletes the demo project of the current user and its associated gcp project
  """
  @spec delete_demo_project_for_user(User.t) :: {:ok, DemoProject.t} | error
  def delete_demo_project_for_user(%User{id: user_id}) do
    get_by_user_id(user_id)
    |> delete_demo_project()
  end

  @doc """
  Will check the create project operation for completion, and if completed, will provision a service account for
  that project to be used in the cloud shell
  """
  @spec poll_demo_project(DemoProject.t) :: {:ok, DemoProject.t} | error
  def poll_demo_project(%DemoProject{state: :enabled} = proj), do: {:ok, proj}

  def poll_demo_project(%DemoProject{state: :ready, enabled_op_id: op_id} = proj) when is_binary(op_id) do
    svcs_conn()
    |> SvcsOperations.serviceusage_operations_get(op_id)
    |> case do
      {:error, %Tesla.Env{status: 404}} ->
        Logger.info "could not find demo project operation #{op_id}"
        enable(proj)
      {:ok, %SvcOperation{done: true, error: %{} = error}} ->
        Logger.info "could not enable services, error: #{inspect(error)}"
        {:ok, proj}
      {:ok, %SvcOperation{done: true}} -> enable(proj)
      _ -> {:ok, proj}
    end
  end

  def poll_demo_project(%DemoProject{ready: true} = proj), do: {:ok, proj}

  def poll_demo_project(%DemoProject{operation_id: op_id} = proj) do
    projects_conn()
    |> Operations.cloudresourcemanager_operations_get(op_id)
    |> case do
      {:error, %Tesla.Env{status: 404}} -> provision(proj)
      {:ok, %Operation{done: true}} -> provision(proj)
      _ -> {:ok, proj}
    end
  end

  def poll_demo_project(nil), do: {:error, [message: "Demo project not found", code: 404]}

  def poll_demo_project(:id, id) do
    get_demo_project(id)
    |> poll_demo_project()
  end

  def poll_demo_project(:user, user_id) do
    get_by_user_id(user_id)
    |> poll_demo_project()
  end

  defp enable(%DemoProject{} = proj) do
    DemoProject.changeset(proj, %{state: :enabled})
    |> Core.Repo.update()
  end

  defp provision(%DemoProject{project_id: proj_id} = demo) do
    projs = projects_conn()
    iams  = iam_conn()

    start_transaction()
    |> add_operation(:billing, fn _ -> enable_billing(proj_id) end)
    |> add_operation(:svcs, fn _  -> enable_services(proj_id) end)
    |> add_operation(:service_account, fn _ ->
      email = "plural@#{proj_id}.iam.gserviceaccount.com"
      with {:error, _} <- IAMProjects.iam_projects_service_accounts_get(iams, proj_id, email),
        do: IAMProjects.iam_projects_service_accounts_create(iams, proj_id, body: %CreateServiceAccountRequest{accountId: "plural"})
    end)
    |> add_operation(:iam, fn %{service_account: %{email: email}} ->
      Core.retry(fn ->
        with {:ok, %{bindings: bindings} = policy} <- Projects.cloudresourcemanager_projects_get_iam_policy(projs, proj_id) do
          bindings =
            add_binding(bindings, email, "roles/owner", "serviceAccount")
            |> add_binding(email, "roles/storage.admin", "serviceAccount")
            |> add_binding(Core.conf(:gcp_identity), "roles/owner", "user")
          Projects.cloudresourcemanager_projects_set_iam_policy(projs, proj_id, body: %SetIamPolicyRequest{
            policy: %{policy | bindings: bindings}
          })
        end
      end)
    end)
    |> add_operation(:creds, fn %{service_account: %{uniqueId: id}} ->
      IAMProjects.iam_projects_service_accounts_keys_create(iams, proj_id, id)
    end)
    |> add_operation(:final, fn %{creds: creds, svcs: %{name: "operations/" <> op_id}} ->
      DemoProject.changeset(demo, %{
        ready: true,
        credentials: format_creds(creds),
        state: :ready,
        enabled_op_id: op_id,
      })
      |> Core.Repo.update()
    end)
    |> execute(extract: :final)
  end

  @doc """
  enables billing on a project
  """
  @spec enable_billing(binary) :: {:ok, term} | error
  def enable_billing(project_id) do
    conn = BillingConnection.new(oauth_token())
    full_id = "projects/#{project_id}"
    with {:ok, billing} <- BillingProjects.cloudbilling_projects_get_billing_info(conn, full_id),
         {:ok, %{billingAccounts: [%{name: name} | _]}} <- BillingAccounts.cloudbilling_billing_accounts_list(conn),
      do: BillingProjects.cloudbilling_projects_update_billing_info(conn, full_id, body: %{billing | billingEnabled: true, billingAccountName: name})
  end

  @spec enable_services(binary) :: {:ok, term} | error
  def enable_services(project_id) do
    svcs_conn()
    |> ServiceUsage.serviceusage_services_batch_enable(
      "projects/#{project_id}",
      body: %BatchEnableServicesRequest{
        serviceIds: [
          "serviceusage.googleapis.com",
          "cloudresourcemanager.googleapis.com",
          "container.googleapis.com"
        ]
      }
    )
  end

  defp add_binding(bindings, email, role, type) do
    case Enum.split_with(bindings, & &1.role == role) do
      {[%Binding{members: members} = bind | rest], bindings} ->
        [%{bind | members: ["#{type}:#{email}" | members]} | rest] ++ bindings
      {_, bindings} -> [binding(email, role, type) | bindings]
    end
  end

  defp format_creds(%ServiceAccountKey{privateKeyData: pk}), do: Base.decode64!(pk)


  defp binding(email, role, type), do: %Binding{members: ["#{type}:#{email}"], role: role}

  defp project_id(%User{}) do
    String.slice("plrl-demo-#{Ecto.UUID.generate()}", 0..29)
  end

  defp projects_conn(), do: ProjectsConnection.new(oauth_token())

  defp iam_conn(), do: IAMConnection.new(oauth_token())

  defp svcs_conn(), do: SvcsConnection.new(oauth_token())

  defp oauth_token() do
    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform")
    token.token
  end

  defp org_id(), do: Core.conf(:gcp_organization)

  defp notify({:ok, %DemoProject{} = p}, :create), do: handle_notify(PubSub.DemoProjectCreated, p)
  defp notify({:ok, %DemoProject{} = p}, :delete), do: handle_notify(PubSub.DemoProjectDeleted, p)
  defp notify(pass, _), do: pass
end
