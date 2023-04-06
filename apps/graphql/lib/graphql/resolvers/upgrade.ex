defmodule GraphQl.Resolvers.Upgrade do
  use GraphQl.Resolvers.Base, model: Core.Schema.Upgrade
  alias Core.Schema.{DeferredUpdate, UpgradeQueue}
  alias Core.Services.{Upgrades}

  def query(UpgradeQueue, _), do: UpgradeQueue
  def query(_, _), do: Upgrade

  def resolve_queue(%{id: id}, %{context: %{current_user: user}}) when is_binary(id),
    do: Upgrades.authorize(id, user)

  def resolve_queue(_, %{context: %{current_user: user}}) do
    %{queue: q} = Core.Repo.preload(user, [:queue])
    {:ok, q}
  end

  def list_queues(_, %{context: %{current_user: user}}) do
    {:ok, Core.Upgrades.Utils.for_user(user)}
  end

  def list_upgrades(args, %{source: q}) do
    Upgrade.for_queue(q.id)
    |> Upgrade.ordered(desc: :id)
    |> paginate(args)
  end

  def list_deferred_updates(%{chart_installation_id: id} = args, _) do
    DeferredUpdate.for_chart_installation(id)
    |> DeferredUpdate.ordered()
    |> paginate(args)
  end

  def list_deferred_updates(%{terraform_installation_id: id} = args, _) do
    DeferredUpdate.for_terraform_installation(id)
    |> DeferredUpdate.ordered()
    |> paginate(args)
  end

  def create_upgrade_queue(%{attributes: attrs}, %{context: %{current_user: user}}),
    do: Upgrades.create_queue(attrs, user)

  def create_upgrade(%{queue: name, attributes: attrs}, %{context: %{repo: repo, current_user: user}}) do
    Map.put(attrs, :repository_id, repo.id)
    |> Upgrades.create_upgrade(name, user)
  end
end
