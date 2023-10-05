defmodule Core.Services.Rbac do
  alias Core.Schema.{User, Role}

  def preload(user) do
    Core.Repo.preload(user, [account: [subscription: :plan], role_bindings: :role, group_role_bindings: :role])
  end

  def evaluate_policy(user, policy) do
    %{groups: user_groups} = Core.Repo.preload(user, [:groups])
    %{bindings: bindings} = Core.Repo.preload(policy, [:bindings])

    {users, groups} = Enum.split_with(bindings, & &1.user_id)
    group_set = Enum.map(groups, & &1.group_id) |> MapSet.new()
    user_group_set = Enum.map(user_groups, & &1.id) |> MapSet.new()

    with false <- Enum.any?(users, & &1.user_id == user.id),
         true <- MapSet.disjoint?(group_set, user_group_set) do
      {:error, "forbidden"}
    else
      _ -> :pass
    end
  end

  def validate(user, action, opts \\ [])
  def validate(user, action, opts) when is_list(opts),
    do: validate(user, action, Map.new(opts))
  def validate(%User{id: id, account_id: aid}, _, %{account: %{id: aid, root_user_id: id}}), do: true
  def validate(%User{account_id: id, roles: %{admin: true}}, _, %{account: %{id: id}}),
    do: true
  def validate(%User{id: id, account: %{root_user_id: id}}, _, %{account: %{}}), do: false
  def validate(%User{id: id, account: %{root_user_id: id}}, _, _), do: true
  def validate(%User{} = user, action, opts) when is_map(opts) do
    user
    |> preload()
    |> User.roles()
    |> maybe_filter(:repo, opts)
    |> maybe_filter(:account, opts)
    |> Enum.any?(&permits_action?(&1, action))
  end

  defp maybe_filter(roles, :repo, %{repository: repository}),
    do: Enum.filter(roles, &matches_repository?(&1, repository))
  defp maybe_filter(roles, :account, %{account: %{id: id}}),
    do: Enum.filter(roles, & &1.account_id == id)
  defp maybe_filter(roles, _, _), do: roles

  defp matches_repository?(%Role{repositories: [_ | _] = repos}, repository) do
    repos
    |> Enum.map(& "^#{String.replace(&1, "*", ".*")}$" |> Regex.compile!())
    |> Enum.any?(&Regex.match?(&1, repository))
  end
  defp matches_repository?(_, _), do: false

  defp permits_action?(%Role{permissions: %Role.Permissions{} = perms}, action),
    do: Map.get(perms, action)
end
