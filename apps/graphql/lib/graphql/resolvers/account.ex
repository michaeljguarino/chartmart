defmodule GraphQl.Resolvers.Account do
  use GraphQl.Resolvers.Base, model: Core.Schema.Account
  import GraphQl.Resolvers.User, only: [with_jwt: 1]
  alias Core.Schema.{Group, GroupMember, Role, RoleBinding, IntegrationWebhook, WebhookLog, OAuthIntegration, DomainMapping, Invite, PlatformPlan}
  alias Core.Services.Accounts

  def query(Group, _), do: Group
  def query(Role, _), do: Role
  def query(RoleBinding, _), do: RoleBinding
  def query(GroupMember, _), do: GroupMember
  def query(IntegrationWebhook, _), do: IntegrationWebhook
  def query(WebhookLog, _), do: WebhookLog
  def query(DomainMapping, _), do: DomainMapping
  def query(_, _), do: Account

  def resolve_account(_, %{context: %{current_user: user}}) do
    Accounts.get_account!(user.account_id)
    |> Core.Repo.preload([subscription: :plan])
    |> ok()
  end

  def available_features(%Account{} = account) do
    PlatformPlan.features()
    |> Enum.into(%{}, & {&1, Core.Services.Payments.has_feature?(account, &1)})
  end
  def available_features(_), do: nil

  def update_account(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Accounts.update_account(attrs, user)

  def list_groups(args, %{context: %{current_user: %{account_id: aid}}}) do
    Group.ordered()
    |> Group.for_account(aid)
    |> maybe_search(Group, args)
    |> paginate(args)
  end

  def list_group_members(%{group_id: group_id} = args, %{context: %{current_user: user}}) do
    with {:ok, _} <- Accessible.accessible(group_id, user, :group) do
      GroupMember.for_group(group_id)
      |> paginate(args)
    end
  end

  def list_roles(args, %{context: %{current_user: %{account_id: aid}}}) do
    Role.ordered()
    |> Role.for_account(aid)
    |> maybe_add_user(args)
    |> maybe_search(Role, args)
    |> paginate(args)
  end

  defp maybe_add_user(q, %{user_id: uid}), do: Role.for_user(q, uid)
  defp maybe_add_user(q, _), do: q

  def list_webhooks(args, %{context: %{current_user: %{account_id: aid}}}) do
    IntegrationWebhook.for_account(aid)
    |> IntegrationWebhook.ordered()
    |> paginate(args)
  end

  def list_webhook_logs(args, %{source: %{id: webhook_id}}) do
    WebhookLog.for_webhook(webhook_id)
    |> WebhookLog.ordered()
    |> paginate(args)
  end

  def list_oauth_integrations(_, %{context: %{current_user: %{account_id: aid}}}) do
    {:ok, OAuthIntegration.for_account(aid)
          |> OAuthIntegration.ordered()
          |> Core.Repo.all()}
  end

  def list_invites(args, %{context: %{current_user: %{account_id: aid}}}) do
    Invite.for_account(aid)
    |> paginate(args)
  end

  def resolve_webhook(%{id: id}, %{context: %{current_user: user}}) do
    Accounts.get_webhook!(id)
    |> Core.Policies.Account.allow(user, :access)
  end

  def resolve_role(%{id: id}, %{context: %{current_user: user}}),
    do: Accessible.accessible(id, user, :role)

  def resolve_invite(%{id: secure_id}, _),
    do: {:ok, Accounts.get_invite(secure_id)}

  def create_service_account(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Accounts.create_service_account(attrs, user)

  def update_service_account(%{attributes: attrs, id: id}, %{context: %{current_user: user}}),
    do: Accounts.update_service_account(attrs, id, user)

  def impersonate_service_account(%{id: id}, %{context: %{current_user: user}}) when is_binary(id) do
    Accounts.impersonate_service_account(:id, id, user)
    |> GraphQl.Resolvers.User.with_jwt()
  end

  def impersonate_service_account(%{email: email}, %{context: %{current_user: user}}) when is_binary(email) do
    Accounts.impersonate_service_account(:email, email, user)
    |> with_jwt()
  end

  def create_invite(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Accounts.create_invite(attrs, user)

  def delete_invite(%{secure_id: id}, %{context: %{current_user: user}}),
    do: Accounts.delete_invite(id, user)
  def delete_invite(%{id: id}, %{context: %{current_user: user}}),
    do: Accounts.delete_invite_by_id(id, user)

  def realize_invite(%{id: id}, _) do
    Accounts.realize_invite(%{}, id)
    |> with_jwt()
  end

  def create_group(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Accounts.create_group(attrs, user)

  def delete_group(%{group_id: group_id}, %{context: %{current_user: user}}),
    do: Accounts.delete_group(group_id, user)

  def update_group(%{attributes: attrs, group_id: group_id}, %{context: %{current_user: user}}),
    do: Accounts.update_group(attrs, group_id, user)

  def create_group_member(%{group_id: group_id, user_id: user_id}, %{context: %{current_user: user}}),
    do: Accounts.create_group_member(%{user_id: user_id}, group_id, user)

  def delete_group_member(%{group_id: group_id, user_id: user_id}, %{context: %{current_user: user}}),
    do: Accounts.delete_group_member(group_id, user_id, user)

  def create_role(%{attributes: attrs}, %{context: %{current_user: user}}) do
    with_permissions(attrs)
    |> Accounts.create_role(user)
  end

  def update_role(%{attributes: attrs, id: id}, %{context: %{current_user: user}}) do
    with_permissions(attrs)
    |> Accounts.update_role(id, user)
  end

  def delete_role(%{id: id}, %{context: %{current_user: user}}),
    do: Accounts.delete_role(id, user)

  def create_webhook(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Accounts.create_webhook(attrs, user)

  def update_webhook(%{id: id, attributes: attrs}, %{context: %{current_user: user}}),
    do: Accounts.update_webhook(attrs, id, user)

  def delete_webhook(%{id: id}, %{context: %{current_user: user}}),
    do: Accounts.delete_webhook(id, user)

  def create_integration(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Accounts.create_oauth_integration(attrs, user)

  def create_zoom_meeting(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Accounts.create_zoom_meeting(attrs, user)

  defp with_permissions(%{permissions: perms} = attrs) when is_list(perms) do
    perm_set = MapSet.new(perms)
    permissions = Role.permissions() |> Enum.map(& {&1, MapSet.member?(perm_set, &1)}) |> Enum.into(%{})
    Map.put(attrs, :permissions, permissions)
  end
  defp with_permissions(attrs), do: attrs
end
