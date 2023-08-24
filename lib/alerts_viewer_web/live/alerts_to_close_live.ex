defmodule AlertsViewerWeb.AlertsToCloseLive do
  @moduledoc """
  LiveView for displaying alerts that we can maybe close.
  """
  use AlertsViewerWeb, :live_view
  alias Alerts.Alert
  alias AlertsViewerWeb.DateTimeHelpers
  alias Routes.{Route, RouteStats, RouteStatsPubSub}
  alias TripUpdates.TripUpdatesPubSub

  @type alert_row :: %{
          alert: Alert.t(),
          block_waivered: boolean(),
          recommended_closure: boolean(),
          stats_by_route: %{Route.id() => RouteStats.t()}
        }

  @max_alert_duration 60
  @min_peak_headway 15

  @impl true
  def mount(_params, _session, socket) do
    bus_routes = Routes.all_bus_routes()

    alerts =
      if(connected?(socket),
        do: Alerts.subscribe(),
        else: []
      )

    stats_by_route = if(connected?(socket), do: RouteStatsPubSub.subscribe(), else: %{})

    sorted_alerts =
      alerts
      |> sorted_alerts()

    recommended_closures = recommended_closures(sorted_alerts, stats_by_route)

    sorted_alerts =
      Enum.map(sorted_alerts, fn alert ->
        case Enum.member?(recommended_closures, alert) do
          true -> alert
          false -> Map.put(alert, :row_class, " text-zinc-300")
        end
      end)

    block_waivered_routes = if(connected?(socket), do: TripUpdatesPubSub.subscribe(), else: [])

    alert_rows =
      create_alert_rows(
        sorted_alerts,
        stats_by_route,
        block_waivered_routes,
        recommended_closures,
        bus_routes
      )

    socket =
      assign(socket,
        bus_routes: bus_routes
      )
      |> stream_configure(:alert_rows, dom_id: &"alert-#{&1.alert.id}")
      |> stream(:alert_rows, alert_rows, reset: true)

    {:ok, socket}
  end

  @spec create_alert_rows([Alert.t()], RouteStats.stats_by_route(), [String.t()], [String.t()], [
          Route.t()
        ]) ::
          [alert_row()]
  def create_alert_rows(
        alerts,
        stats_by_route,
        block_waivered_routes,
        recommended_closures,
        bus_routes
      ) do
    Enum.map(alerts, fn alert ->
      route_ids = route_names_from_alert(alert, bus_routes)
      has_block_waiver = Enum.any?(route_ids, &Enum.member?(block_waivered_routes, &1))
      has_recommended_closure = Enum.member?(recommended_closures, alert)
      selected_stats_by_route = Map.take(stats_by_route, route_ids)

      %{
        alert: alert,
        block_waivered: has_block_waiver,
        recommended_closure: has_recommended_closure,
        stats_by_route: selected_stats_by_route
      }
    end)
  end

  @impl true
  def handle_info({:alerts, alerts}, socket) do
    sorted_alerts = sorted_alerts(alerts)
    stats_by_route = RouteStatsPubSub.all()
    recommended_closures = recommended_closures(sorted_alerts, stats_by_route)
    block_waivered_routes = TripUpdatesPubSub.all()

    sorted_alerts =
      Enum.map(sorted_alerts, fn alert ->
        case Enum.member?(recommended_closures, alert) do
          true -> alert
          false -> Map.put(alert, :row_class, " text-zinc-300")
        end
      end)

    alert_rows =
      create_alert_rows(
        sorted_alerts,
        stats_by_route,
        block_waivered_routes,
        recommended_closures,
        socket.assigns.bus_routes
      )

    socket =
      socket
      |> stream(:alert_rows, alert_rows, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stats_by_route, stats_by_route}, socket) do
    sorted_alerts = sorted_alerts(Alerts.all())

    recommended_closures = recommended_closures(sorted_alerts(Alerts.all()), stats_by_route)

    block_waivered_routes = TripUpdatesPubSub.all()

    alert_rows =
      create_alert_rows(
        sorted_alerts,
        stats_by_route,
        block_waivered_routes,
        recommended_closures,
        socket.assigns.bus_routes
      )

    socket
    |> stream(:alert_rows, alert_rows, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:block_waivered_routes, block_waivered_routes}, socket) do
    stats_by_route = RouteStatsPubSub.all()
    sorted_alerts = sorted_alerts(Alerts.all())

    recommended_closures = recommended_closures(sorted_alerts(Alerts.all()), stats_by_route)

    alert_rows =
      create_alert_rows(
        sorted_alerts,
        stats_by_route,
        block_waivered_routes,
        recommended_closures,
        socket.assigns.bus_routes
      )

    socket
    |> stream(:alert_rows, alert_rows, reset: true)

    {:noreply, socket}
  end

  def recommended_closures(alerts, stats_by_route) do
    Enum.filter(
      alerts,
      &recommending_closure?(
        &1,
        @max_alert_duration,
        @min_peak_headway,
        stats_by_route
      )
    )
  end

  @spec route_names_from_alert(Alert.t(), [Route.t()]) :: [String.t()]
  def route_names_from_alert(alert, bus_routes) do
    alert
    |> Alert.route_ids()
    |> Enum.map(&Routes.get_by_id(bus_routes, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Route.name/1)
  end

  @spec sorted_alerts([Alert.t()]) :: [Alert.t()]
  defp sorted_alerts(alerts) do
    alerts
    |> filtered_by_bus()
    |> filtered_by_delay_type()
    |> Enum.sort_by(
      & &1.created_at,
      {:asc, DateTime}
    )
  end

  @spec delay_alert?(Route.t(), [Alert.t()]) :: boolean()
  def delay_alert?(%Route{id: route_id}, alerts),
    do: Enum.any?(alerts, &Alert.matches_route_and_effect(&1, route_id, :delay))

  @spec filtered_by_bus([Alert.t()]) :: [Alert.t()]
  defp filtered_by_bus(alerts), do: Alerts.by_service(alerts, "3")

  @spec filtered_by_delay_type([Alert.t()]) :: [Alert.t()]
  defp filtered_by_delay_type(alerts), do: Alerts.by_effect(alerts, "delay")

  @spec recommending_closure?(
          Alert.t(),
          integer(),
          integer(),
          RouteStats.stats_by_route()
        ) ::
          boolean()
  defp recommending_closure?(
         alert,
         duration_threshold_in_minutes,
         peak_threshold_in_minutes,
         stats_by_route
       ) do
    current_time = DateTime.now!("America/New_York")
    route_ids = Alert.route_ids(alert)

    duration = DateTime.diff(current_time, alert.created_at, :minute)

    headways =
      route_ids
      |> Enum.map(fn route_id ->
        stats_by_route
        |> RouteStats.max_headway_deviation(route_id)
        |> DateTimeHelpers.seconds_to_minutes()
      end)
      |> Enum.reject(&is_nil/1)

    peak =
      case headways do
        [_ | _] -> Enum.max(headways)
        [] -> nil
      end

    duration >= duration_threshold_in_minutes and
      (!is_nil(peak) and peak <= peak_threshold_in_minutes)
  end

  defp format_stats(alert, stats_by_route, stats_function) do
    alert
    |> Alert.route_ids()
    |> Enum.map(fn route_id ->
      stats_by_route
      |> stats_function.(route_id)
      |> seconds_to_minutes()
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(",")
  end
end
