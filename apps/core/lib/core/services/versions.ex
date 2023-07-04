defmodule Core.Services.Versions do
  use Core.Services.Base
  import Core.Policies.Version

  alias Core.PubSub
  alias Core.Policies.Repository, as: RepoPolicies
  alias Core.Services.{Charts, Terraform, Tests}
  alias Core.Schema.{Version, Repository, User, VersionTag, PackageScan, ChartInstallation, TerraformInstallation}

  @type tool_type :: :helm | :terraform
  @type error :: {:error, term}
  @type version_resp :: {:ok, Version.t} | error

  def get_version(:helm, id, version),
    do: Core.Repo.get_by(Version, chart_id: id, version: version)
  def get_version(:terraform, id, version),
    do: Core.Repo.get_by(Version, terraform_id: id, version: version)

  def get_tag(:helm, id, tag),
    do: Core.Repo.get_by(VersionTag, chart_id: id, tag: tag)
  def get_tag(:terraform, id, tag),
    do: Core.Repo.get_by(VersionTag, terraform_id: id, tag: tag)

  def get_tag(%Version{} = version, tag) do
    tool = derive_tool(version)
    resource_id = resource_id(version)
    get_tag(tool, resource_id, tag)
  end

  @doc """
  Creates a new version for a chart.  Fails if the user is not the publisher
  """
  @spec create_version(map, tool_type, binary, User.t) :: version_resp
  def create_version(attrs, tool, id, %User{} = user) do
    version = stringish_fetch(attrs, :version)
    tool_id = tool_id(tool)

    start_transaction()
    |> add_operation(:version, fn _ ->
      case get_version(tool, id, version) do
        %Version{} = v -> v
        _ -> struct(Version, %{tool_id => id, inserted: true})
      end
      |> Version.changeset(attrs)
      |> allow(user, :create)
      |> when_ok(&Core.Repo.insert_or_update/1)
    end)
    |> add_operation(:bump, fn %{version: %{version: v}} ->
      update_latest_version(tool, id, v)
    end)
    |> add_operation(:tag, fn %{version: %{id: version_id}} ->
      case get_tag(tool, id, "latest") do
        %VersionTag{} = tag -> tag
        _ -> struct(VersionTag, %{tool_id => id, tag: "latest"})
      end
      |> VersionTag.changeset(%{version_id: version_id})
      |> Core.Repo.insert_or_update()
    end)
    |> execute()
    |> case do
      {:ok, %{version: v, bump: r}} -> {:ok, %{v | tool => r}}
      error -> error
    end
  end

  def update_latest_version(:helm, id, version) do
    Charts.get_chart(id)
    |> Charts.update_latest_version(version)
  end

  def update_latest_version(:terraform, id, version) do
    Terraform.get_tf!(id)
    |> Terraform.update_latest_version(version)
  end

  def update_version(attrs, version_id, %User{} = user) do
    start_transaction()
    |> add_operation(:version, fn _ ->
      Core.Repo.get!(Version, version_id)
      |> allow(user, :edit)
    end)
    |> maybe_insert_tags(attrs)
    |> add_operation(:update, fn %{version: version} ->
      version
      |> Version.changeset(Map.delete(attrs, :tags))
      |> Core.Repo.update()
      |> when_ok(&Core.Repo.preload(&1, [:tags]))
    end)
    |> execute(extract: :update)
    |> notify(:update, user)
  end

  @doc """
  manually tag all installed versions with the list specified
  """
  @spec release(Repository.t, [binary], User.t) :: {:ok, map} | error
  def release(%Repository{id: repo_id} = repo, tags, %User{} = user) do
    with {:ok, _} <- RepoPolicies.allow(repo, user, :edit) do
      installed_versions(repo_id, user)
      |> Tests.promote(tags, user)
    end
  end

  @spec installed_versions(binary, User.t) :: [binary]
  def installed_versions(repo_id, %User{id: user_id}) do
    Parallax.new()
    |> Parallax.operation(:chart, fn ->
      ChartInstallation.for_repo(repo_id)
      |> ChartInstallation.for_user(user_id)
      |> ChartInstallation.preload([:version])
      |> Core.Repo.all()
      |> Enum.map(& &1.version)
    end)
    |> Parallax.operation(:tf, fn ->
      TerraformInstallation.for_repo(repo_id)
      |> TerraformInstallation.for_user(user_id)
      |> TerraformInstallation.preload([:version])
      |> Core.Repo.all()
      |> Enum.map(& &1.version)
    end)
    |> Parallax.execute()
    |> Enum.flat_map(fn {_, results} -> results end)
  end

  def record_scan(scan, %Version{} = version) when is_binary(scan) do
    with {:ok, scan} <- Poison.decode(scan, as: Core.Scan.type()),
      do: record_scan(scan, version)
  end

  def record_scan(%{results: scan_result}, %Version{id: version_id}) do
    case Core.Repo.get_by(PackageScan, version_id: version_id) do
      %PackageScan{} = scan -> Core.Repo.preload(scan, [:errors, :violations])
      nil -> %PackageScan{version_id: version_id}
    end
    |> PackageScan.changeset(scan_attributes(scan_result))
    |> Core.Repo.insert_or_update()
  end

  def scan_attributes(%{violations: violations, scan_errors: errors, scan_summary: summary}) do
    %{
      violations: scan_violations(violations),
      errors: scan_errors(errors),
      grade: grade(summary),
    }
  end

  def create_tag(%Version{} = version, tag) do
    tool = derive_tool(version)
    resource_id = resource_id(version)
    tool_id = tool_id(tool)

    case get_tag(tool, resource_id, tag) do
      %VersionTag{} = tag -> tag
      _ -> struct(VersionTag, %{tool_id => resource_id, tag: tag})
    end
    |> VersionTag.changeset(%{version_id: version.id})
    |> Core.Repo.insert_or_update()
  end

  defp scan_violations([_ | _] = violations) do
    violations
    |> Enum.map(&Map.put(&1, :severity, String.downcase(&1.severity)))
    |> Enum.map(&Map.from_struct/1)
  end
  defp scan_violations(_), do: []

  defp scan_errors([_ | _] = errors) do
    Enum.map(errors, & %{message: &1.errMsg})
  end
  defp scan_errors(_), do: []

  defp grade(%{high: v}) when v > 0, do: :d
  defp grade(%{medium: v}) when v > 0, do: :c
  defp grade(%{low: v}) when v > 0, do: :b
  defp grade(_), do: :a

  defp maybe_insert_tags(transaction, %{tags: tags}) do
    tags
    |> Enum.filter(& &1.tag != "latest")
    |> Enum.reduce(transaction, fn tag, xaction ->
      add_operation(xaction, {:tag, tag.tag}, fn %{version: version} ->
        create_tag(version, tag.tag)
      end)
    end)
  end

  defp tool_id(:helm), do: :chart_id
  defp tool_id(:terraform), do: :terraform_id

  defp derive_tool(%Version{chart_id: id}) when not is_nil(id), do: :helm
  defp derive_tool(%Version{terraform_id: id}) when not is_nil(id), do: :terraform

  defp resource_id(%Version{chart_id: id}) when not is_nil(id), do: id
  defp resource_id(%Version{terraform_id: id}) when not is_nil(id), do: id

  def notify(%Version{} = v, :create, user),
    do: handle_notify(PubSub.VersionCreated, v, actor: user)
  def notify({:ok, %Version{inserted: true} = v}, :upsert, user),
    do: handle_notify(PubSub.VersionCreated, v, actor: user)
  def notify({:ok, %Version{} = v}, :upsert, user),
    do: handle_notify(PubSub.VersionUpdated, v, actor: user)
  def notify({:ok, %Version{} = v}, :create, user),
    do: handle_notify(PubSub.VersionCreated, v, actor: user)
  def notify({:ok, %Version{} = v}, :update, user),
    do: handle_notify(PubSub.VersionUpdated, v, actor: user)
  def notify(error, _, _), do: error
end
