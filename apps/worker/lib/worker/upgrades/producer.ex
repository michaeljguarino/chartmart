defmodule Worker.Upgrades.Producer do
  use GenStage
  use Worker.Base
  require Logger
  alias Core.Services.Upgrades

  @max 20
  @poll :timer.seconds(5)

  defmodule State, do: defstruct [:demand, :type, :draining]

  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts[:type], name: opts[:name])
  end

  def init(type) do
    :timer.send_interval(@poll, :poll)
    {:producer, %State{demand: 0, type: type}}
  end

  def handle_info(:poll, %State{draining: true} = state), do: empty(state)
  def handle_info(:poll, %State{demand: demand} = state) do
    Logger.info "checking for new upgrades"
    deliver(demand, %{state | draining: FT.K8S.TrafficDrainHandler.draining?()})
  end

  def handle_demand(_, %State{draining: true} = state), do: empty(state)
  def handle_demand(demand, %State{demand: remaining} = state) when demand > 0 do
    deliver(demand + remaining, state)
  end

  def handle_demand(_, state), do: empty(state)

  def child_spec(arg) do
    default = %{
      id: arg[:name],
      start: {__MODULE__, :start_link, [arg]}
    }

    Supervisor.child_spec(default, [])
  end

  defp deliver(demand, %State{type: type} = state) do
    case Upgrades.poll_deferred_updates(type, min(demand, @max)) do
      {:ok, updates} when is_list(updates) ->
        {:noreply, updates, %{state | demand: demand - length(updates)}}
      _ -> empty(%{state | demand: demand})
    end
  end
end
