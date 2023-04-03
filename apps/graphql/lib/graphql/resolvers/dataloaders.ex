defmodule GraphQl.InstallationLoader do
  alias Core.Schema.Installation

  def data(_) do
    Dataloader.KV.new(&query/2, max_concurrency: 1)
  end

  def query(_, ids) do
    insts = fetch_insts(ids)
    Map.new(ids, & {&1, insts[&1]})
  end

  def fetch_insts(ids) do
    MapSet.to_list(ids)
    |> Installation.for_ids()
    |> Core.Repo.all()
    |> Map.new(& {&1.id, &1})
  end
end

defmodule GraphQl.ShellLoader do
  alias Core.Schema.CloudShell

  def data(_) do
    Dataloader.KV.new(&query/2, max_concurrency: 1)
  end

  def query(_, ids) do
    shells = fetch_shells(ids)
    Map.new(ids, & {&1, !!shells[&1]})
  end

  def fetch_shells(ids) do
    MapSet.to_list(ids)
    |> CloudShell.for_users()
    |> Core.Repo.all()
    |> Map.new(& {&1.user_id, &1})
  end
end
