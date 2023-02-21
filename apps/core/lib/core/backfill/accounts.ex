defmodule Core.Backfill.Accounts do
  alias Core.Schema.{Account}

  def usage() do
    Account.usage()
    |> Core.Repo.all()
    |> Core.throttle(count: 10, pause: 1)
    |> Enum.each(fn %{id: id, users: u, clusters: c} ->
      Account.for_id(id)
      |> Core.Repo.update_all(set: [user_count: u, cluster_count: c])
    end)
  end

  def grandfather() do
    grandfathered = Timex.now() |> Timex.shift(days: 60)
    Core.Repo.update_all(Account, set: [grandfathered_until: grandfathered])
  end

  def wipe_dangling() do
    Account.dangling_root()
    |> Core.Repo.update_all(set: [root_user_id: nil])
  end
end
