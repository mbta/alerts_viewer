defmodule AlertsViewerWeb.BusLive do
  @moduledoc """
  LiveView for presenting a list of bus routes and showing which currently have active alerts.
  """
  use AlertsViewerWeb, :live_view

  alias Alerts.Alert
  alias Routes.{Route, RouteStats, RouteStatsPubSub}

  @impl true
  def mount(_params, _session, socket) do
    delay_alert_algorithm_components =
      Application.get_env(:alerts_viewer, :delay_alert_algorithm_components)

    algorithm_options = algorithm_options(delay_alert_algorithm_components)
    current_algorithm = hd(delay_alert_algorithm_components)

    bus_routes = Routes.all_bus_routes()
    bus_alerts = if(connected?(socket), do: Alerts.subscribe() |> filtered_by_bus(), else: [])
    stats_by_route = if(connected?(socket), do: RouteStatsPubSub.subscribe(), else: %{})

    routes_with_current_alerts = Enum.filter(bus_routes, &delay_alert?(&1, bus_alerts))

    socket =
      assign(socket,
        algorithm_options: algorithm_options,
        current_algorithm: current_algorithm,
        filter_rows?: false,
        bus_routes: bus_routes,
        stats_by_route: stats_by_route,
        routes_with_current_alerts: routes_with_current_alerts,
        routes_with_recommended_alerts: []
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("select-algorithm", %{"algorithm" => module_str}, socket) do
    current_algorithm = String.to_atom(module_str)
    {:noreply, assign(socket, current_algorithm: current_algorithm)}
  end

  @impl true
  def handle_event("set-filter-rows", %{"filter_rows" => filter_rows_str}, socket) do
    filter_rows? = filter_rows_str == "true"
    {:noreply, assign(socket, filter_rows?: filter_rows?)}
  end

  @impl true
  def handle_info({:alerts, alerts}, socket) do
    bus_alerts = filtered_by_bus(alerts)

    routes_with_current_alerts =
      Enum.filter(socket.assigns.bus_routes, &delay_alert?(&1, bus_alerts))

    socket = assign(socket, routes_with_current_alerts: routes_with_current_alerts)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:stats_by_route, stats_by_route}, socket) do
    socket = assign(socket, stats_by_route: stats_by_route)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:updated_routes_with_recommended_alerts, routes_with_recommended_alerts},
        socket
      ) do
    socket = assign(socket, routes_with_recommended_alerts: routes_with_recommended_alerts)
    {:noreply, socket}
  end

  @spec delay_alert?(Route.t(), [Alert.t()]) :: boolean()
  def delay_alert?(%Route{id: route_id}, alerts),
    do: Enum.any?(alerts, &Alert.matches_route_and_effect(&1, route_id, :delay))

  @doc """
  Display the results of a prediction.

  ## Examples

      <.result actual={true} prediction={false} />
  """
  attr(:actual, :boolean)
  attr(:prediction, :boolean)

  def result(assigns) do
    ~H"""
    <div class={if true_result?(@actual, @prediction), do: "text-green-700", else: "text-red-700"}>
      <%= result_label(@actual, @prediction) %>
    </div>
    """
  end

  @spec true_result?(boolean(), boolean()) :: boolean()
  defp true_result?(true, true), do: true
  defp true_result?(false, false), do: true
  defp true_result?(_, _), do: false

  @spec result_label(boolean(), boolean()) :: String.t()
  defp result_label(true, true), do: "TP"
  defp result_label(false, false), do: "TN"
  defp result_label(false, true), do: "FP"
  defp result_label(true, false), do: "FN"

  @type module_option :: {String.t(), module()}
  @spec algorithm_options([module()]) :: [module_option()]
  defp algorithm_options(modules), do: Enum.map(modules, &module_lable_tuple/1)

  @spec module_lable_tuple(module()) :: module_option()
  defp module_lable_tuple(module), do: {humane_name(module), module}

  @spec humane_name(module()) :: String.t()
  defp humane_name(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
    |> String.replace_suffix("Component", "")
  end

  @spec filtered_by_bus([Alert.t()]) :: [Alert.t()]
  defp filtered_by_bus(alerts), do: Alerts.by_service(alerts, "3")

  @spec maybe_filtered([Route.t()], boolean(), [Route.t()], [Route.t()]) :: [Route.t()]
  defp maybe_filtered(routes, true, routes_with_current_alerts, routes_with_recommended_alerts) do
    Enum.filter(routes, fn route ->
      Enum.member?(routes_with_current_alerts, route) or
        Enum.member?(routes_with_recommended_alerts, route)
    end)
  end

  defp maybe_filtered(routes, false, _, _), do: routes
end
