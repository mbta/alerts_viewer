defmodule SnapshotLogger.SnapshotLogger do
  @moduledoc """
  Logs algorithm snapshots on a cadence.
  """
  use GenServer
  require Logger
  alias Alerts.Alert
  alias AlertsViewer.DelayAlertAlgorithm
  alias Routes.{Route, RouteStatsPubSub}

  @cadence 5 * 60 * 1000

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(_opts) do
    delay_alert_algorithm_modules =
      Application.get_env(:alerts_viewer, :delay_alert_algorithm_components)

    bus_alerts = Alerts.subscribe() |> filtered_by_bus() |> filtered_by_delay_type()
    bus_routes = Routes.all_bus_routes()
    stats_by_route = RouteStatsPubSub.subscribe()
    routes_with_current_alerts = Enum.filter(bus_routes, &delay_alert?(&1, bus_alerts))
    schedule_logs()

    {:ok,
     %{
       bus_routes: bus_routes,
       stats_by_route: stats_by_route,
       routes_with_current_alerts: routes_with_current_alerts,
       delay_alert_algorithm_modules: delay_alert_algorithm_modules,
       routes_with_recommended_alerts: []
     }}
  end

  @impl GenServer
  def handle_info({:stats_by_route, stats_by_route}, state) do
    {:noreply, Map.put(state, :stats_by_route, stats_by_route)}
  end

  @impl GenServer
  def handle_info({:alerts, alerts}, state) do
    bus_alerts = filtered_by_bus(alerts) |> filtered_by_delay_type()

    routes_with_current_alerts = Enum.filter(state.bus_routes, &delay_alert?(&1, bus_alerts))

    state =
      Map.put(
        state,
        :routes_with_current_alerts,
        routes_with_current_alerts
      )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:log, state) do
    schedule_logs()

    snapshot =
      state.delay_alert_algorithm_modules
      |> Enum.reduce(%{}, fn module, acc ->
        snapshot_data = make_snapshot(module, state)
        Map.put(acc, module_name(module), snapshot_data)
      end)
      |> Jason.encode!()

    Logger.info(snapshot)

    {:noreply, state}
  end

  defp make_snapshot(module, state) do
    algorithm_data = module.snapshot(state.bus_routes, state.stats_by_route)

    algorithm_data
    |> Enum.map(fn [
                     parameters: %{value: value},
                     routes_with_recommended_alerts: routes_with_recommended_alerts
                   ] ->
      results =
        prediction_results(
          state.bus_routes,
          state.routes_with_current_alerts,
          routes_with_recommended_alerts
        )

      %{
        value: value,
        accuracy: PredictionResults.accuracy(results),
        recall: PredictionResults.recall(results),
        precision: PredictionResults.precision(results)
      }
    end)
  end

  defp schedule_logs do
    Process.send_after(self(), :log, @cadence)
  end

  @spec prediction_results([Route.t()], [Route.t()], [Route.t()]) :: PredictionResults.t()
  defp prediction_results(routes, routes_with_current_alerts, routes_with_recommended_alerts) do
    predictions = Enum.map(routes, &Enum.member?(routes_with_recommended_alerts, &1))
    targets = Enum.map(routes, &Enum.member?(routes_with_current_alerts, &1))

    PredictionResults.new(predictions, targets)
  end

  defp module_name(module) do
    DelayAlertAlgorithm.humane_name(module)
    |> String.replace(" ", "_")
    |> String.downcase()
    |> String.to_atom()
  end

  @spec filtered_by_bus([Alert.t()]) :: [Alert.t()]
  defp filtered_by_bus(alerts), do: Alerts.by_service(alerts, "3")

  @spec filtered_by_delay_type([Alert.t()]) :: [Alert.t()]
  defp filtered_by_delay_type(alerts), do: Alerts.by_effect(alerts, "delay")

  @spec delay_alert?(Route.t(), [Alert.t()]) :: boolean()
  def delay_alert?(%Route{id: route_id}, alerts),
    do: Enum.any?(alerts, &Alert.matches_route_and_effect(&1, route_id, :delay))
end
