defmodule GraphQl.Resolvers.User do
  use GraphQl.Resolvers.Base, model: Core.Schema.User
  alias Core.Services.{Users, Accounts, Encryption}
  alias Core.Schema.{
    Publisher,
    PersistedToken,
    Webhook,
    Group,
    Notification,
    ImpersonationPolicy,
    ImpersonationPolicyBinding,
    OIDCTrustRelationship,
    PublicKey,
    AccessTokenAudit,
    EabCredential,
    KeyBackup
  }

  def data(args) do
    Dataloader.Ecto.new(Core.Repo,
      query: &query/2,
      default_params: filter_context(args),
      run_batch: &run_batch/5
    )
  end

  def query(Publisher, _), do: Publisher
  def query(Webhook, _), do: Webhook
  def query(Group, _), do: Group
  def query(PublicKey, _), do: PublicKey
  def query(ImpersonationPolicy, _), do: ImpersonationPolicy
  def query(ImpersonationPolicyBinding, _), do: ImpersonationPolicyBinding
  def query(OIDCTrustRelationship, _), do: OIDCTrustRelationship
  def query(_, _), do: User

  def run_batch(_, _, :repositories, publishers, repo_opts) do
    repos =
      Enum.map(publishers, fn %{id: id} -> id end)
      |> Publisher.for_ids()
      |> Publisher.repositories()
      |> Core.Repo.all(repo_opts)
      |> Enum.group_by(& &1.publisher_id)

    Enum.map(publishers, fn %{id: id} -> Map.get(repos, id, []) end)
  end

  def run_batch(queryable, query, col, inputs, repo_opts) do
    Dataloader.Ecto.run_batch(Core.Repo, queryable, query, col, inputs, repo_opts)
  end

  def resolve_user(%{id: id}, %{context: %{current_user: user}}),
    do: Users.accessible(id, user)

  def resolve_publisher(%{id: id}, _),
    do: {:ok, Users.get_publisher!(id)}
  def resolve_publisher(_, %{context: %{current_user: user}}),
    do: {:ok, Users.get_publisher_by_owner(user.id)}

  def resolve_reset_token(%{id: id}, _), do: {:ok, Users.get_reset_token!(id)}

  def resolve_token(%{id: id}, %{context: %{current_user: %{id: user_id}}}) do
    Core.Repo.get!(PersistedToken, id)
    |> case do
      %{user_id: ^user_id} = token -> {:ok, token}
      _ -> {:error, "forbidden"}
    end
  end

  def fetch_key_backup(%{name: name}, %{context: %{current_user: %{id: user_id}}}),
    do: {:ok, Encryption.get_backup(user_id, name)}

  def list_users(args, %{context: %{current_user: %{account_id: id}}}) do
    User.ordered()
    |> User.for_account(id)
    |> maybe_search(User, args)
    |> is_service_account(args)
    |> paginate(args)
  end

  def list_keys(%{emails: emails} = args, %{context: %{current_user: user}}) do
    PublicKey.for_emails(emails, user.account_id)
    |> PublicKey.ordered()
    |> paginate(args)
  end

  def list_keys(args, %{context: %{current_user: user}}) do
    PublicKey.for_user(user.id)
    |> PublicKey.ordered()
    |> paginate(args)
  end

  def list_token_audits(args, %{source: %{id: id}}) do
    AccessTokenAudit.for_token(id)
    |> AccessTokenAudit.ordered()
    |> paginate(args)
  end

  def audit_metrics(_, %{source: %{id: id}}) do
    cutoff = Timex.now() |> Timex.shift(months: -1)
    AccessTokenAudit.for_token(id)
    |> AccessTokenAudit.created_after(cutoff)
    |> AccessTokenAudit.aggregate()
    |> Core.Repo.all()
    |> ok()
  end

  defp is_service_account(q, %{all: true}), do: q
  defp is_service_account(q, %{service_account: true}),
    do: User.service_account(q, :yes)
  defp is_service_account(q, _),
    do: User.service_account(q, :no)

  def search_users(%{incident_id: id} = args, %{context: %{current_user: user}}) do
    incident =
      Core.Services.Incidents.get_incident!(id)
      |> Core.Repo.preload([:creator, :owner])

    with {:ok, incident} <- Core.Policies.Incidents.allow(incident, user, :access) do
      User.ordered()
      |> User.for_incident(incident)
      |> maybe_search(User, args)
      |> paginate(args)
    end
  end

  def list_publishers(%{account_id: aid} = args, _) do
    Publisher.for_account(aid)
    |> Publisher.ordered()
    |> paginate(args)
  end

  def list_publishers(%{publishable: true} = args, %{context: %{current_user: user}}) do
    Publisher.for_account(user.account_id)
    |> Publisher.publishable(user)
    |> Publisher.ordered()
    |> paginate(args)
  end

  def list_publishers(args, _) do
    Publisher.ordered()
    |> paginate(args)
  end

  def list_tokens(args, %{context: %{current_user: user}}) do
    PersistedToken.for_user(user.id)
    |> PersistedToken.ordered()
    |> paginate(args)
  end

  def list_webhooks(args, %{context: %{current_user: user}}) do
    Webhook.for_user(user.id)
    |> Webhook.ordered()
    |> paginate(args)
  end

  def list_notifications(args, %{context: %{current_user: user}}) do
    Notification.for_user(user.id)
    |> Notification.ordered()
    |> filter_notifs(args)
    |> paginate(args)
  end

  def list_key_backups(args, %{context: %{current_user: user}}) do
    KeyBackup.for_user(user.id)
    |> KeyBackup.ordered()
    |> paginate(args)
  end

  def filter_notifs(query, %{cli: true}), do: Notification.cli(query)
  def filter_notifs(query, %{incident_id: id}) when is_binary(id),
    do: Notification.for_incident(query, id)
  def filter_notifs(query, _), do: query

  def create_webhook(%{attributes: %{url: url}}, %{context: %{current_user: user}}),
    do: Users.upsert_webhook(url, user)

  def create_token(_, %{context: %{current_user: user}}),
    do: Users.create_persisted_token(user)

  def delete_token(%{id: id}, %{context: %{current_user: user}}),
    do: Users.delete_persisted_token(id, user)

  def create_event(%{attributes: attrs}, %{context: %{current_user: user}}) do
    case Users.create_event(attrs, user) do
      {:ok, _} -> {:ok, true}
      _ -> {:ok, false}
    end
  end

  def login_method(%{email: email} = args, _), do: Users.login_method(email, args[:host])

  def login_user(%{email: email, password: pwd} = args, _) do
    Users.login_user(email, pwd)
    |> with_jwt()
    |> activate_token(args)
  end

  def passwordless_login(%{token: token}, _) do
    Users.passwordless_login(token)
    |> with_jwt()
  end

  def poll_login_token(%{token: token} = args, _) do
    Users.poll_login_token(token)
    |> with_jwt()
    |> activate_token(args)
  end

  def signup_user(%{invite_id: id, attributes: attrs} = args, _) when is_binary(id) do
    Map.put(attrs, :account, args[:account] || %{})
    |> Accounts.realize_invite(id)
    |> with_jwt()
  end

  def signup_user(%{attributes: attrs} = args, _) do
    Map.put(attrs, :account, args[:account] || %{})
    |> Users.create_user()
    |> activate_token(args)
    |> with_jwt()
  end

  def ping_webhook(%{repo: repo, id: webhook_id} = args, _) do
    webhook = Users.get_webhook!(webhook_id)

    Users.post_webhook(%{
      repository: repo,
      message: Map.get(args, :message, "webhook ping")
    }, webhook)
    |> case do
      {:ok, %{body: body, status_code: code, headers: headers}} when is_list(headers) ->
        {:ok, %{body: body, status_code: code, headers: Map.new(headers)}}
      error -> error
    end
  end

  def update_user(%{id: id, attributes: attrs}, %{context: %{current_user: user}}) when is_binary(id),
    do: Users.update_user(attrs, id, user)
  def update_user(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Users.update_user(attrs, user)

  def delete_user(%{id: id}, %{context: %{current_user: user}}),
    do: Users.delete_user(id, user)

  def create_publisher(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Users.create_publisher(attrs, user)

  def update_publisher(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Users.update_publisher(attrs, user)

  def read_notifications(args, %{context: %{current_user: user}}) do
    {count, _} = Users.read_notifications(args, user)
    {:ok, count}
  end

  def create_reset_token(%{attributes: attrs}, _) do
    with {:ok, _} <- Users.create_reset_token(attrs),
      do: {:ok, true}
  end

  def realize_reset_token(%{attributes: attrs, id: id}, _) do
    with {:ok, _} <- Users.realize_reset_token(id, attrs),
      do: {:ok, true}
  end

  def create_public_key(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Users.create_public_key(attrs, user)

  def delete_public_key(%{id: id}, %{context: %{current_user: user}}),
    do: Users.delete_public_key(id, user)

  def create_trust_relationship(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Users.create_trust_relationship(attrs, user)

  def delete_trust_relationship(%{id: id}, %{context: %{current_user: user}}),
    do: Users.delete_trust_relationship(id, user)

  def oidc_token(%{id_token: token, provider: provider, email: email}, _) do
    with {:ok, token, _} <- Users.oidc_token(provider, token, email),
      do: {:ok, token}
  end

  def device_login(_, _),
    do: Users.device_login()

  def get_eab_key(%{cluster: cluster, provider: prov}, %{context: %{current_user: user}}),
    do: Users.get_eab_key(cluster, prov, user)

  def delete_eab_key(%{cluster: cluster, provider: prov}, %{context: %{current_user: user}})
      when is_binary(cluster) do
    case Users.fetch_eab_key(cluster, prov, user) do
      nil -> {:error, :not_found}
      %{id: id} -> Users.delete_eab_key(id, user)
    end
  end
  def delete_eab_key(%{id: id}, %{context: %{current_user: user}}),
    do: Users.delete_eab_key(id, user)

  def list_eab_keys(_, %{context: %{current_user: user}}) do
    keys = EabCredential.for_user(user.id) |> Core.Repo.all()
    {:ok, keys}
  end

  def destroy_cluster(attrs, %{context: %{current_user: user}}) do
    with :ok <- Users.destroy_cluster(attrs, user),
      do: {:ok, true}
  end

  def create_key_backup(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Encryption.create_backup(attrs, user)

  def delete_key_backup(%{name: name}, %{context: %{current_user: user}}),
    do: Encryption.delete_backup(name, user)

  @colors ~w(#6b5b95 #feb236 #d64161 #ff7b25 #103A50 #CDCCC2 #FDC401 #8E5B3C #020001 #2F415B)

  def background_color(%{id: id}) do
    stripped = String.replace(id, "-", "")
    {integral, _} = Integer.parse(stripped, 16)
    Enum.at(@colors, rem(integral, length(@colors)))
  end

  def with_jwt({:ok, user}) do
    with {:ok, token, _} <- Core.Guardian.encode_and_sign(user),
        do: {:ok, %{user | jwt: token}}
  end
  def with_jwt(error), do: error

  def activate_token({:ok, %User{} = user}, %{device_token: token}) when is_binary(token) do
    with {:ok, _} <- Users.activate_login_token(token, user),
      do: {:ok, user}
  end
  def activate_token(pass, _), do: pass
end
