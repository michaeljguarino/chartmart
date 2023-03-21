defmodule Core.Policies.Payments do
  use Piazza.Policy
  import Core.Policies.Utils
  alias Core.Schema.{Account, Plan, Subscription, PlatformPlan, PlatformSubscription, User}
  alias Core.Policies.{Publisher}

  def can?(user, %PlatformPlan{}, _),
    do: check_rbac(user, :billing, account: user.account)

  def can?(user, %PlatformSubscription{}, _),
    do: check_rbac(user, :billing, account: user.account)

  def can?(user, %Account{} = account, :pay), do: check_rbac(user, :billing, account: account)

  def can?(user, %Plan{} = plan, action) do
    %{repository: %{publisher: pub}} = Core.Repo.preload(plan, [repository: :publisher])
    Publisher.can?(user, pub, action)
  end

  def can?(%User{id: user_id}, %Subscription{} = sub, :delete) do
    case Core.Repo.preload(sub, [:installation]) do
      %{installation: %{user_id: ^user_id}} -> :pass
      _ -> {:error, :forbidden}
    end
  end

  def can?(%User{id: user_id}, %Subscription{} = sub, _) do
    case Core.Repo.preload(sub, [:installation, :plan]) do
      %{plan: %Plan{repository_id: repo_id}, installation: %{user_id: ^user_id, repository_id: repo_id}} ->
        :pass
      _ -> {:error, :forbidden}
    end
  end

  def can?(user, %Ecto.Changeset{} = cs, action),
    do: can?(user, apply_changes(cs), action)

  def can?(_, _, _), do: {:error, :forbidden}
end
