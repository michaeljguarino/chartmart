defmodule Core.Services.Repositories do
  use Core.Services.Base
  import Core.Policies.Repository

  alias Core.PubSub
  alias Core.Services.{Users, Locks, Shell.Demo, Shell}
  alias Core.Auth.Jwt
  alias Core.Clients.Hydra
  alias Core.Schema.{
    Repository,
    Installation,
    User,
    DockerRepository,
    DockerImage,
    LicenseToken,
    License,
    Integration,
    Subscription,
    Plan,
    Artifact,
    OIDCProvider,
    ApplyLock,
    VersionTag,
    Contributor
  }
  alias Piazza.Crypto.RSA

  @type error :: {:error, term}
  @type repository_resp :: {:ok, Repository.t} | error

  @spec get_installation!(binary) :: Installation.t
  def get_installation!(id),
    do: Core.Repo.get!(Installation, id)

  @spec get_installation(binary, binary) :: Installation.t | nil
  def get_installation(user_id, repo_id) do
    Core.Repo.get_by(Installation, repository_id: repo_id, user_id: user_id)
  end

  def get_installation_by_key!(key),
    do: Core.Repo.get_by!(Installation, license_key: key)

  def get_installation_by_key(key),
    do: Core.Repo.get_by(Installation, license_key: key)

  @spec get_repository!(binary) :: Repository.t
  def get_repository!(id), do: Core.Repo.get(Repository, id)

  @spec get_repository_by_name!(binary) :: Repository.t
  def get_repository_by_name!(name),
    do: Core.Repo.get_by!(Repository, name: name)

  @spec get_repository_by_name(binary) :: Repository.t | nil
  def get_repository_by_name(name),
    do: Core.Repo.get_by(Repository, name: name)

  def get_license_token(token),
    do: Core.Repo.get_by(LicenseToken, token: token)

  @spec contributor?(Repository.t | binary, User.t | binary) :: boolean
  def contributor?(%Repository{id: repo_id}, %User{id: user_id}), do: contributor?(repo_id, user_id)
  def contributor?(repo_id, user_id) do
    Contributor.for_user(user_id)
    |> Contributor.for_repository(repo_id)
    |> Core.Repo.exists?()
  end

  def get_artifact(repo_id, name, platform, arch) do
    Core.Repo.get_by(
      Artifact,
      repository_id: repo_id,
      name: name,
      platform: platform,
      arch: arch
    )
  end

  def get_dkr_image!(image_id), do: Core.Repo.get!(DockerImage, image_id)

  def get_dkr_repository(repo_name, dkr_name) do
    DockerRepository.for_repository_name(repo_name)
    |> Core.Repo.get_by!(name: dkr_name)
  end

  def get_dkr_image(repo_name, dkr_name, tag) do
    DockerRepository.for_repository_name(repo_name)
    |> DockerRepository.for_name(dkr_name)
    |> DockerImage.for_repositories()
    |> DockerImage.for_tag(tag)
    |> Core.Repo.one()
  end

  def get_oidc_provider_by_client!(client_id) do
    Core.Repo.get_by!(OIDCProvider, client_id: client_id)
    |> Core.Repo.preload([:bindings, installation: :repository])
  end

  @doc """
  Finds all distinct version tags in the repository that can be followed for upgrades
  """
  @spec upgrade_channels(Repository.t) :: [binary]
  def upgrade_channels(%Repository{id: id}) do
    VersionTag.for_repository(id)
    |> VersionTag.distinct()
    |> Core.Repo.all()
  end

  @doc """
  Creates a new repository for the user's publisher

  Will throw if there is no publisher
  """
  @spec create_repository(map, User.t) :: repository_resp
  def create_repository(attrs, %User{} = user) do
    publisher = Users.get_publisher_by_owner!(user.id)
    create_repository(attrs, publisher.id, user)
  end

  @doc """
  Creates a repository for a publisher id.  Will fail if the user does not have publish
  permissions, or is not the owner of the publisher.
  """
  @spec create_repository(map, binary, User.t) :: repository_resp
  def create_repository(attrs, publisher_id, %User{} = user) do
    start_transaction()
    |> add_operation(:repo, fn _ ->
      %Repository{publisher_id: publisher_id}
      |> Repository.changeset(add_contributors(attrs))
      |> allow(user, :create)
      |> when_ok(:insert)
    end)
    |> add_operation(:licensed, fn %{repo: repo} ->
      generate_keys(repo)
    end)
    |> execute(extract: :licensed)
    |> notify(:create, user)
  end

  @doc """
  Updates the given repository.

  Fails if the user is not the publisher
  """
  @spec update_repository(map, binary, User.t) :: repository_resp
  def update_repository(attrs, repo_id, %User{} = user) do
    get_repository!(repo_id)
    |> Core.Repo.preload([:integration_resource_definition, :tags, :contributors])
    |> Repository.changeset(add_contributors(attrs))
    |> allow(user, :edit)
    |> when_ok(:update)
    |> notify(:update, user)
  end

  defp add_contributors(%{contributors: [_ | _] = emails} = attrs) do
    users = Users.for_emails(emails)
    Map.put(attrs, :contributors, Enum.map(users, & %{user_id: &1.id}))
  end
  defp add_contributors(attrs), do: attrs

  @doc """
  Deletes the repository.  This might be deprecated as it's inherently unsafe.

  Fails if the user is not the publisher.
  """
  @spec delete_repository(binary, User.t) :: repository_resp
  def delete_repository(repo_id, %User{} = user) do
    get_repository!(repo_id)
    |> allow(user, :edit)
    |> when_ok(:delete)
  end

  @doc """
  Creates or updates a repository depending on whether one exists for `name`.  All
  access policies for the delegated operations apply
  """
  @spec upsert_repository(map, binary, binary, User.t) :: repository_resp
  def upsert_repository(attrs, name, publisher_id, %User{} = user) do
    case get_repository_by_name(name) do
      %Repository{id: id} -> update_repository(attrs, id, user)
      nil -> create_repository(Map.put(attrs, :name, name), publisher_id, user)
    end
  end

  @doc """
  Returns the list of docker accesses available for `user` against the
  given repository
  """
  @spec authorize_docker(binary, binary, User.t | nil) :: [:push | :pull]
  def authorize_docker(repo_name, dkr_name, nil) do
    DockerRepository.for_repository_name(repo_name)
    |> Core.Repo.get_by(name: dkr_name)
    |> case do
      %DockerRepository{public: true} -> [:pull]
      _ -> []
    end
  end

  def authorize_docker(repo_name, dkr_name, %User{} = user) do
    repo = get_repository_by_name!(repo_name)
           |> Core.Repo.preload([:publisher])

    Parallax.new()
    |> Parallax.operation(:push, fn -> allow(repo, user, :edit) end)
    |> Parallax.operation(:pull, fn -> allow(repo, user, :pull) end)
    |> Parallax.execute()
    |> Enum.filter(fn
      {_, {:ok, _}} -> true
      _ -> false
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.concat(authorize_docker(repo_name, dkr_name, nil))
    |> Enum.uniq()
  end

  @doc """
  Persists a given docker image with the given tag.  Called by the docker
  registry notification webhook.
  """
  @spec create_docker_image(binary, binary, binary, User.t) :: {:ok, DockerImage.t} | error
  def create_docker_image(repo, tag, digest, user) do
    [cm_repo | rest] = String.split(repo, "/")
    cm_repo = get_repository_by_name!(cm_repo)

    start_transaction()
    |> add_operation(:repo, fn _ ->
      Enum.join(rest, "/")
      |> upsert_docker_repo(cm_repo)
    end)
    |> add_operation(:image, fn %{repo: repo} ->
      upsert_image(tag, digest, repo)
    end)
    |> execute()
    |> notify(:create, user)
  end

  @doc """
  Used to atomically fetch a list of docker images while continuously scanning
  """
  @spec poll_docker_images(integer, integer) :: {:ok, [DockerImage.t]} | error
  def poll_docker_images(scan_interval, limit) do
    owner = Ecto.UUID.generate()
    start_transaction()
    |> add_operation(:lock, fn _ -> Locks.acquire("rollout", owner) end)
    |> add_operation(:fetch, fn _ ->
      DockerImage.scanned_before(scan_interval)
      |> DockerImage.with_limit(limit)
      |> Core.Repo.all()
      |> ok()
    end)
    |> add_operation(:imgs, fn %{fetch: fetch} ->
      Enum.map(fetch, & &1.id)
      |> DockerImage.for_ids()
      |> DockerImage.selected()
      |> Core.Repo.update_all(set: [scanned_at: Timex.now()])
      |> elem(1)
      |> ok()
    end)
    |> add_operation(:release, fn _ -> Locks.release("rollout") end)
    |> execute(extract: :imgs)
  end

  @doc """
  Appends vulnerabilities to a docker image
  """
  @spec add_vulnerabilities([map], DockerImage.t) :: {:ok, DockerImage.t} | error
  def add_vulnerabilities(vulns, image) do
    Core.Repo.preload(image, [:vulnerabilities])
    |> DockerImage.vulnerability_changeset(%{
      vulnerabilities: vulns,
      scan_completed_at: Timex.now(),
      scan_retries: 0,
      grade: grade(vulns)
    })
    |> Core.Repo.update()
  end

  @doc """
  Determines if a scan should be retries or completed
  """
  @spec retry_scan(DockerImage.t) :: {:ok, DockerImage.t} | error
  def retry_scan(%DockerImage{scan_retries: r} = img) when r >= 2 do
    Ecto.Changeset.change(img, %{scan_completed_at: Timex.now(), scan_retries: 0})
    |> Core.Repo.update()
  end
  def retry_scan(%DockerImage{scan_retries: r} = img) do
    Ecto.Changeset.change(img, %{scan_retries: r + 1})
    |> Core.Repo.update()
  end

  defp grade(vulns) when is_list(vulns) do
    vulns
    |> Enum.reduce(%{}, fn %{severity: severity}, acc ->
      Map.update(acc, severity, 0, & &1 + 1)
    end)
    |> case do
      %{critical: _} -> :f
      %{high: _} -> :d
      %{medium: _} -> :c
      %{low: _} -> :b
      _ -> :a
    end
  end
  defp grade(_), do: :a

  defp upsert_docker_repo(name, %Repository{id: id}) do
    case Core.Repo.get_by(DockerRepository, repository_id: id, name: name) do
      nil -> %DockerRepository{repository_id: id, name: name}
      %DockerRepository{} = repo -> repo
    end
    |> DockerRepository.changeset()
    |> Core.Repo.insert_or_update()
  end

  defp upsert_image(nil, _, _), do: {:ok, nil}
  defp upsert_image(tag, digest, %DockerRepository{id: id}) do
    case Core.Repo.get_by(DockerImage, docker_repository_id: id, tag: tag) do
      nil -> %DockerImage{docker_repository_id: id, tag: tag}
      %DockerImage{} = repo -> repo
    end
    |> DockerImage.changeset(%{digest: digest})
    |> Core.Repo.insert_or_update()
  end

  def update_docker_repository(attrs, id, %User{} = user) do
    Core.Repo.get!(DockerRepository, id)
    |> DockerRepository.changeset(attrs)
    |> allow(user, :edit)
    |> when_ok(:update)
    |> notify(:update, user)
  end

  @doc """
  Constructs a docker-compliant jwt for the given repo and scopes.
  """
  @spec docker_token([binary | atom], binary, User.t | nil) :: {:ok, binary} | {:error, term}
  def docker_token(scopes, repo_name, user) do
    signer = Jwt.signer()
    access = [%{"type" => "repository", "name" => repo_name, "actions" => scopes}]
    with {:ok, claims} <- Jwt.generate_claims(%{"sub" => dkr_sub(user), "access" => access}),
         {:ok, token, _} <- Jwt.encode_and_sign(claims, signer),
      do: {:ok, token}
  end

  defp dkr_sub(%{email: email}), do: email
  defp dkr_sub(_), do: ""

  @doc """
  Constructs a dummy jwt for user on docker login
  """
  @spec dkr_login_token(User.t | nil) :: {:ok, binary} | {:error, term}
  def dkr_login_token(nil), do: {:error, :invalid_password}
  def dkr_login_token(%User{} = user) do
    signer = Jwt.signer()
    with {:ok, claims} <- Jwt.generate_claims(%{"sub" => user.email, "access" => []}),
         {:ok, token, _} <- Jwt.encode_and_sign(claims, signer),
      do: {:ok, token}
  end


  @doc """
  Creates or updates the given integration for the repo.

  Fails if the user is not the publisher
  """
  @spec upsert_integration(map, binary, User.t) :: {:ok, Integration.t} | {:error, term}
  def upsert_integration(%{name: name} = attrs, repo_id, %User{} = user) do
    repo = get_repository!(repo_id) |> Core.Repo.preload([:integration_resource_definition])
    pub  = Users.get_publisher_by_owner(user.id)
    case Core.Repo.get_by(Integration, name: name, repository_id: repo_id) do
      %Integration{} = int -> Core.Repo.preload(int, [:tags])
      _ -> %Integration{repository_id: repo_id, name: name, publisher_id: pub && pub.id}
    end
    |> Integration.changeset(Map.put(attrs, :publisher_id, pub && pub.id))
    |> Integration.validate(repo.integration_resource_definition)
    |> allow(user, :edit)
    |> when_ok(&Core.Repo.insert_or_update/1)
  end

  @doc """
  Creates a new installation for a repository for the given user
  """
  @spec create_installation(map, binary | Repository.t, User.t) :: {:ok, Installation.t} | {:error, term}
  def create_installation(attrs, %Repository{id: repo_id} = repo, %User{} = user) do
    %Installation{repository_id: repo_id, user_id: user.id, auto_upgrade: true}
    |> Installation.changeset(
      add_track_tag(attrs, repo)
      |> Map.put_new(:context, %{})
      |> Map.put(:source, installation_source(user))
    )
    |> allow(user, :create)
    |> when_ok(:insert)
    |> notify(:create, user)
  end
  def create_installation(attrs, id, user),
    do: create_installation(attrs, get_repository!(id), user)

  defp add_track_tag(attrs, %Repository{default_tag: tag}) when is_binary(tag) and byte_size(tag) > 0,
    do: Map.put(attrs, :track_tag, tag)
  defp add_track_tag(attrs, _), do: attrs

  def installation_source(%User{id: id}) do
    Core.local_cache({:inst_source, id}, fn ->
      case {Demo.has_demo?(id), Shell.has_shell?(id)} do
        {true, _} -> :demo
        {_, true} -> :shell
        _ -> :default
      end
    end)
  end

  @doc """
  Updates the given installation.

  Fails if the user is not the original installer.
  """
  @spec update_installation(map, binary, User.t) :: {:ok, Installation.t} | {:error, term}
  def update_installation(attrs, inst_id, %User{} = user) do
    get_installation!(inst_id)
    |> Installation.changeset(attrs)
    |> allow(user, :edit)
    |> when_ok(:update)
    |> notify(:update, user)
  end

  @doc """
  Deletes the given installation.  If there is also a subscription, will delete it as well.

  Fails if the user is not the installer.
  """
  @spec delete_installation(binary | Installation.t, User.t) :: {:ok, Installation.t} | {:error, term}
  def delete_installation(%Installation{} = installation, %User{} = user) do
    start_transaction()
    |> add_operation(:subscription, fn _ ->
      Core.Repo.preload(installation, [:subscription])
      |> case do
        %{subscription: %Subscription{} = sub} ->
          Core.Services.Payments.cancel_subscription(sub, user)
        _ -> {:ok, nil}
      end
    end)
    |> add_operation(:installation, fn _ ->
      installation
      |> allow(user, :edit)
      |> when_ok(:delete)
    end)
    |> execute(extract: :installation)
    |> notify(:delete, user)
  end
  def delete_installation(inst_id, user), do: get_installation!(inst_id) |> delete_installation(user)

  @doc """
  Will delete all installations for a user and reset their provider pin
  """
  @spec reset_installations(User.t) :: {:ok, integer} | {:error, term}
  def reset_installations(%User{} = user) do
    Installation.for_user(user.id)
    |> Core.Repo.all()
    |> Enum.reduce(start_transaction(), fn inst, tx ->
      add_operation(tx, inst.id, fn _ ->
        delete_installation(inst, user)
      end)
    end)
    |> add_operation(:user, fn _ -> Users.update_provider(nil, user) end)
    |> execute()
    |> when_ok(fn results ->
      Map.keys(results)
      |> Enum.reject(& &1 == :user)
      |> Enum.count()
    end)
  end

  @oidc_scopes "profile code openid offline_access offline"
  @grant_types ~w(authorization_code refresh_token client_credentials)

  @doc """
  Creates a new oidc provider for a given installation, enabling a log-in with plural experience
  """
  @spec create_oidc_provider(map, binary, User.t) :: {:ok, OIDCProvider.t} | {:error, term}
  def create_oidc_provider(attrs, installation_id, %User{} = user) do
    start_transaction()
    |> add_operation(:installation, fn _ ->
      get_installation!(installation_id)
      |> allow(user, :edit)
    end)
    |> add_operation(:client, fn _ ->
      Map.take(attrs, [:redirect_uris])
      |> Map.put(:scope, @oidc_scopes)
      |> Map.put(:grant_types, @grant_types)
      |> Map.put(:token_endpoint_auth_method, oidc_auth_method(attrs.auth_method))
      |> Hydra.create_client()
    end)
    |> add_operation(:oidc_provider, fn
      %{installation: %{id: id}, client: %{client_id: cid, client_secret: secret}} ->
        %OIDCProvider{installation_id: id}
        |> OIDCProvider.changeset(Map.merge(attrs, %{client_id: cid, client_secret: secret}))
        |> Core.Repo.insert()
    end)
    |> execute(extract: :oidc_provider)
    |> notify(:create)
  end

  @doc """
  Inserts or updates the oidc provider for an installation
  """
  @spec upsert_oidc_provider(map, binary, User.t) :: {:ok, OIDCProvider.t} | {:error, term}
  def upsert_oidc_provider(attrs, installation_id, %User{} = user) do
    case Core.Repo.get_by(OIDCProvider, installation_id: installation_id) do
      %OIDCProvider{} ->
        update_oidc_provider(attrs, installation_id, user)
      _ -> create_oidc_provider(attrs, installation_id, user)
    end
  end

  @doc """
  Updates the spec of an installation's oidc provider
  """
  @spec update_oidc_provider(map, binary, User.t) :: {:ok, OIDCProvider.t} | {:error, term}
  def update_oidc_provider(attrs, installation_id, %User{} = user) do
    start_transaction()
    |> add_operation(:installation, fn _ ->
      get_installation!(installation_id)
      |> Core.Repo.preload([oidc_provider: :bindings])
      |> allow(user, :edit)
    end)
    |> add_operation(:client, fn
      %{installation: %{oidc_provider: %{client_id: id, auth_method: auth_method}}} ->
        attrs = Map.take(attrs, [:redirect_uris])
                |> Map.put(:scope, @oidc_scopes)
                |> Map.put(:token_endpoint_auth_method, oidc_auth_method(auth_method))
        Hydra.update_client(id, attrs)
    end)
    |> add_operation(:oidc_provider, fn %{installation: %{oidc_provider: provider}} ->
      provider
      |> OIDCProvider.changeset(attrs)
      |> Core.Repo.update()
    end)
    |> execute(extract: :oidc_provider)
    |> notify(:update)
  end

  @doc """
  Gets or creates a new apply lock to use in plural apply commands.  The user performing this
  action will own the lock until manually released
  """
  @spec acquire_apply_lock(binary, User.t) :: {:ok, ApplyLock.t} | {:error, term}
  def acquire_apply_lock(repository_id, %User{} = user) do
    case Core.Repo.get_by(ApplyLock, repository_id: repository_id) do
      %ApplyLock{} = lock -> lock
      nil -> %ApplyLock{repository_id: repository_id}
    end
    |> allow(user, :create)
    |> when_ok(fn lock ->
      ApplyLock.changeset(lock, %{owner_id: user.id})
      |> Core.Repo.insert_or_update()
    end)
  end

  @doc """
  Updates the lock and releases ownership by the given user
  """
  @spec release_apply_lock(map, binary, User.t) :: {:ok, ApplyLock.t} | {:error, term}
  def release_apply_lock(attrs, repository_id, %User{id: user_id} = user) do
    case Core.Repo.get_by(ApplyLock, repository_id: repository_id) do
      %ApplyLock{owner_id: ^user_id} = lock -> flush_lock(lock, attrs, user)
      nil -> flush_lock(%ApplyLock{repository_id: repository_id}, attrs, user)
      _ -> {:error, :not_found}
    end
  end

  defp flush_lock(lock, attrs, user) do
    lock
    |> allow(user, :create)
    |> when_ok(&ApplyLock.changeset(&1, Map.put(attrs, :owner_id, nil)))
    |> when_ok(&Core.Repo.insert_or_update/1)
  end

  defp oidc_auth_method(:basic), do: "client_secret_basic"
  defp oidc_auth_method(:post), do: "client_secret_post"

  @doc """
  Deletes an oidc provider and its hydra counterpart
  """
  @spec delete_oidc_provider(binary, User.t) :: {:ok, OIDCProvider.t} | {:error, term}
  def delete_oidc_provider(installation_id, %User{} = user) do
    start_transaction()
    |> add_operation(:installation, fn _ ->
      get_installation!(installation_id)
      |> Core.Repo.preload([oidc_provider: :bindings])
      |> allow(user, :edit)
    end)
    |> add_operation(:client, fn %{installation: %{oidc_provider: %{client_id: id}}} ->
      with :ok <- Hydra.delete_client(id),
        do: {:ok, nil}
    end)
    |> add_operation(:oidc_provider, fn %{installation: %{oidc_provider: provider}} ->
      Core.Repo.delete(provider)
    end)
    |> execute(extract: :oidc_provider)
  end

  @doc """
  Creates a new artifact for the repository, representing a downloadable resource
  like a cli, desktop app, etc.

  Fails if the user is not the publisher
  """
  @spec create_artifact(map, binary, User.t) :: {:ok, Artifact.t} | {:error, term}
  def create_artifact(%{name: name, platform: plat} = attrs, repository_id, %User{} = user) do
    attrs = Map.put_new(attrs, :arch, "amd64")

    get_artifact(repository_id, name, plat, attrs.arch)
    |> case do
      %Artifact{} = art -> art
      _ -> %Artifact{repository_id: repository_id}
    end
    |> Artifact.changeset(attrs)
    |> allow(user, :edit)
    |> when_ok(&Core.Repo.insert_or_update/1)
  end

  @doc """
  Generates a refresh token for the license, constructs the policy given
  the current subscription (or free if there are no plans configured).

  Fails if the installation has no suscription but the repository has
  plans available.
  """
  @spec generate_license(Installation.t) :: {:ok, binary | nil}
  def generate_license(%Installation{} = installation) do
    %{repository: repo} = installation =
      Core.Repo.preload(installation, [:repository, [subscription: :plan]])

    with {:ok, %{token: token}} <- upsert_license_token(installation),
         {:ok, policy} <- mk_policy(installation, Core.Services.Payments.has_plans?(repo.id)) do
      License.new(policy: policy, refresh_token: token, secrets: repo.secrets)
      |> Jason.encode!()
      |> RSA.encrypt(ExPublicKey.loads!(repo.private_key))
    else
      _ -> {:ok, nil}
    end
  end

  def license(%Installation{} = installation) do
    handle_notify(PubSub.LicensePing, installation)

    %{repository: repo} = installation =
      Core.Repo.preload(installation, [:repository, [subscription: :plan]])

    with {:ok, policy} <- mk_policy(installation, Core.Services.Payments.has_plans?(repo.id)),
      do: {:ok, License.new(policy: policy, secrets: repo.secrets)}
  end

  defp mk_policy(%Installation{subscription: %Subscription{line_items: %{items: items}, plan: plan} = sub}, _) do
    limits = Enum.into(items, %{}, fn %{dimension: dim} ->
      {dim, Subscription.dimension(sub, dim)}
    end)
    features = Plan.features(plan)
    {:ok, %{limits: limits, features: features, plan: plan.name, free: false}}
  end
  defp mk_policy(_, false), do: {:ok, %{free: true}}
  defp mk_policy(_, _), do: :error

  @doc """
  Constructs a new license file with the given license token.
  """
  @spec refresh_license(LicenseToken.t) :: {:ok, binary} | {:error, :not_found}
  def refresh_license(%LicenseToken{installation: %Installation{} = installation}),
    do: generate_license(installation)
  def refresh_license(token) when is_binary(token) do
    Core.Repo.get_by!(LicenseToken, token: token)
    |> Core.Repo.preload([:installation])
    |> refresh_license()
  end
  def refresh_license(_), do: {:error, :not_found}

  @doc """
  Generates an rsa key pair and persists it to the repository
  """
  @spec generate_keys(Repository.t) :: {:ok, Repository.t} | {:error, term}
  def generate_keys(%Repository{} = repo) do
    with {:ok, keypair} <- RSA.generate_keypair(),
         {:ok, {priv, pub}} <- RSA.pem_encode(keypair) do
      repo
      |> Repository.key_changeset(%{private_key: priv, public_key: pub})
      |> Core.Repo.update()
    end
  end

  @doc """
  Self-explanatory
  """
  @spec upsert_license_token(Installation.t) :: {:ok, LicenseToken.t} | {:error, term}
  def upsert_license_token(%Installation{id: id}) do
    case Core.Repo.get_by(LicenseToken, installation_id: id) do
      %LicenseToken{} = token -> token
      nil -> %LicenseToken{}
    end
    |> LicenseToken.changeset(%{installation_id: id})
    |> Core.Repo.insert_or_update()
  end

  @doc """
  Adds the readme and license information to a repository where possible
  """
  @spec hydrate(Repository.t) :: {:ok, Repository.t} | nil
  def hydrate(repo) do
    with {branch, readme} <- fetch_readme(repo) do
      repo
      |> Repository.changeset(%{readme: readme, main_branch: branch, license: fetch_license(repo)})
      |> Core.Repo.update()
    end
  end

  @doc """
  Attempts to grab the contents of a repo's github readme and returns the result
  """
  @spec fetch_readme(Repository.t) :: {binary, binary} | nil
  def fetch_readme(%Repository{git_url: "https://github.com" <> _ = url}),
    do: readme_fetch("#{url}/raw/{branch}/README.md")
  def fetch_readme(%Repository{git_url: "https://gitlab.com" <> _ = url}),
    do: readme_fetch("#{url}/-/raw/{branch}/README.md")
  def fetch_readme(_), do: nil

  @doc """
  Attempts to extract the license for a repo from github where possible
  """
  @spec fetch_license(Repository.t) :: %{name: binary, url: binary} | nil
  def fetch_license(%Repository{git_url: "https://github.com/" <> rest}) do
    headers = [{"accept", "application/vnd.github.v3+json"}]
    with [owner, repo | _] <- String.split(rest, "/"),
         repo <- String.trim(repo, ".git"),
         {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.get("https://api.github.com/repos/#{owner}/#{repo}/license", headers),
         {:ok, %{"license" => license, "html_url" => url}} <- Jason.decode(body) do
      %{name: license["name"], url: url}
    else
    _ -> nil
    end
  end
  def fetch_license(_), do: nil

  defp readme_fetch(url) do
    Enum.find_value(~w(main master), fn branch ->
      String.replace(url, "{branch}", branch)
      |> HTTPoison.get([], follow_redirect: true)
      |> case do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {branch, body}
        _ -> nil
      end
    end)
  end

  @doc """
  Returns the docs for a repo if present.  This will get the icon url, untar it, and reformat the result for passthrough to gql.
  """
  @spec documentation(Repository.t) :: {:ok, [{binary, binary}]} | error
  def documentation(%Repository{docs: nil}), do: {:ok, []}
  def documentation(%Repository{docs: docs} = repo) do
    url = Core.Storage.url({docs, repo}, :original)
    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.get(url, [], follow_redirect: true),
         {:ok, result} <- :erl_tar.extract({:binary, body}, [:memory, :compressed]) do
      {:ok, Enum.map(result, fn {p, c} -> {clean_path(p), c} end)}
    end
  end

  defp clean_path(p) when is_binary(p) do
    case String.split(p, ["/", "\\"]) do
      [_ | rest] -> Enum.join(rest, "/")
      _ -> p
    end
  end
  defp clean_path(p), do: to_string(p) |> clean_path()

  @doc """
  Returns whether a user can `:access` the repository.
  """
  @spec authorize(binary, User.t) :: {:ok, Repository.t} | {:error, term}
  def authorize(repo_id, %User{} = user) when is_binary(repo_id) do
    get_repository!(repo_id)
    |> authorize(user)
  end
  def authorize(%Repository{} = repo, user),
    do: allow(repo, user, :access)

  defp notify({:ok, %Installation{} = inst}, :create, user),
    do: handle_notify(PubSub.InstallationCreated, inst, actor: user)
  defp notify({:ok, %Installation{} = inst}, :update, user),
    do: handle_notify(PubSub.InstallationUpdated, inst, actor: user)
  defp notify({:ok, %Installation{} = inst}, :delete, user),
    do: handle_notify(PubSub.InstallationDeleted, inst, actor: user)

  defp notify({:ok, %DockerRepository{} = repo}, :update, user),
    do: handle_notify(PubSub.DockerRepositoryUpdated, repo, actor: user)

  defp notify({:ok, %Repository{} = repo}, :create, user),
    do: handle_notify(PubSub.RepositoryCreated, repo, actor: user)
  defp notify({:ok, %Repository{} = repo}, :update, user),
    do: handle_notify(PubSub.RepositoryUpdated, repo, actor: user)

  defp notify({:ok, %{image: %DockerImage{} = img}} = res, :create, user) do
    img = Core.Repo.preload(img, [docker_repository: :repository])
    handle_notify(PubSub.DockerImageCreated, img, actor: user)
    res
  end

  defp notify(pass, _, _), do: pass

  defp notify({:ok, %OIDCProvider{} = oidc}, :create),
    do: handle_notify(PubSub.OIDCProviderCreated, oidc)
  defp notify({:ok, %OIDCProvider{} = oidc}, :update),
    do: handle_notify(PubSub.OIDCProviderUpdated, oidc)

  defp notify(pass, _), do: pass
end
