defmodule AlertsViewerWeb.StopAlertsLive do
  @moduledoc """
  LiveView for displaying alerts that we can maybe close.
  """
  use AlertsViewerWeb, :live_view
  alias Alerts.Alert
  alias Routes.{Route, RouteStats, RouteStatsPubSub}
  alias TripUpdates.TripUpdatesPubSub

  @impl true
  def mount(_params, _session, socket) do
    bus_alerts =
      if(connected?(socket),
        do: Alerts.subscribe(),
        else: []
      )

    stats_by_route = if(connected?(socket), do: RouteStatsPubSub.subscribe(), else: %{})

    alerts_by_route = alerts_by_route(bus_alerts)

    block_waivered_routes = if(connected?(socket), do: TripUpdatesPubSub.subscribe(), else: [])

    socket =
      assign(socket,
        stats_by_route: stats_by_route,
        block_waivered_routes: block_waivered_routes,
        alerts_by_route: alerts_by_route
      )

    {:ok, socket}
  end

  @impl true

  def handle_info({:alerts, alerts}, socket) do
    alerts_by_route = alerts_by_route(alerts)
    {:noreply, assign(socket, alerts_by_route: alerts_by_route)}
  end

  @impl true
  def handle_info({:stats_by_route, stats_by_route}, socket) do
    {:noreply, assign(socket, stats_by_route: stats_by_route)}
  end

  @impl true
  def handle_info({:block_waivered_routes, block_waivered_routes}, socket) do
    {:noreply, assign(socket, block_waivered_routes: block_waivered_routes)}
  end

  def alert_duration(alert) do
    (DateTime.diff(DateTime.now!("America/New_York"), alert.created_at) / 3600)
    |> Float.round(1)
  end

  @spec seconds_to_minutes(nil | number) :: nil | float
  def seconds_to_minutes(nil), do: nil

  def seconds_to_minutes(seconds) do
    (seconds / 60) |> round
  end

  defp alerts_by_route(alerts) do
    alerts
    |> filtered_by_bus()
    |> filtered_by_delay_type()
    |> Alerts.by_route()
    |> Map.to_list()
    |> Enum.map(fn {head, tail} -> {String.to_atom(head), tail} end)
    |> Enum.sort_by(
      fn {_head, tail} -> Enum.max(Enum.map(tail, & &1.created_at), DateTime) end,
      :asc
    )
  end

  @spec delay_alert?(Route.t(), [Alert.t()]) :: boolean()
  def delay_alert?(%Route{id: route_id}, alerts),
    do: Enum.any?(alerts, &Alert.matches_route_and_effect(&1, route_id, :delay))

  @spec filtered_by_bus([Alert.t()]) :: [Alert.t()]
  defp filtered_by_bus(alerts), do: Alerts.by_service(alerts, "3")

  @spec filtered_by_delay_type([Alert.t()]) :: [Alert.t()]
  defp filtered_by_delay_type(alerts), do: Alerts.by_effect(alerts, "delay")
end
