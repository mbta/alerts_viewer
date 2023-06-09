defmodule AlertsViewer.DelayAlertAlgorithm.AlgorithmComponent do
  @moduledoc """
  Component for controlling the delay alert recommendation algorithm.
  """

  use AlertsViewerWeb, :live_component
  alias Routes.{Route, RouteStats}

  @impl true
  def update(assigns, socket) do
    routes_default = Map.get(assigns, :routes, [])
    routes = Map.get(assigns, :routes, routes_default)
    stats_by_route_default = Map.get(assigns, :stats_by_route, %{})
    stats_by_route = Map.get(assigns, :stats_by_route, stats_by_route_default)

    algorithm_module = Map.get(assigns, :current_algorithm)

    # sets slider to initial value if first load or if algorithm is changed by parent
    value_set_at =
      case is_nil(Map.get(socket.assigns, :value_set_at)) or
             Map.get(assigns, :value_set_at) == :reset do
        true -> algorithm_module.initial_value()
        false -> socket.assigns.value_set_at
      end

    routes_with_recommended_alerts =
      Enum.filter(
        routes,
        &recommending_alert?(
          &1,
          stats_by_route,
          value_set_at,
          algorithm_module.algorithm()
        )
      )

    send(self(), {
      :updated_routes_with_recommended_alerts,
      routes_with_recommended_alerts
    })

    {:ok,
     assign(socket,
       routes: routes,
       stats_by_route: stats_by_route,
       algorithm_module: algorithm_module,
       min_value: algorithm_module.min_value(),
       max_value: algorithm_module.max_value(),
       value_set_at: value_set_at,
       interval_value: algorithm_module.interval_value()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex space-x-16 items-center">
      <.controls_form phx-change="update-controls" phx-target={@myself}>
        <.input
          type="range"
          name="value_set_at"
          value={@value_set_at}
          min={@min_value}
          max={@max_value}
          step={@interval_value}
          label="Minumum Value"
        />
        <span class="ml-2">
          <%= @value_set_at %>
        </span>
      </.controls_form>

      <.link
        navigate={~p"/bus/snapshot/#{Atom.to_string(@algorithm_module)}"}
        replace={false}
        target="_blank"
        class="bg-transparent hover:bg-zinc-500 text-zinc-700 font-semibold hover:text-white py-2 px-4 border border-zinc-500 hover:border-transparent hover:no-underline rounded"
      >
        Snapshot
      </.link>
    </div>
    """
  end

  @impl true
  def handle_event("update-controls", %{"value_set_at" => value_set_at}, socket) do
    routes_with_recommended_alerts =
      Enum.filter(
        socket.assigns.routes,
        &recommending_alert?(
          &1,
          socket.assigns.stats_by_route,
          value_set_at,
          socket.assigns.algorithm_module.algorithm()
        )
      )

    send(self(), {:updated_routes_with_recommended_alerts, routes_with_recommended_alerts})

    {:noreply, assign(socket, value_set_at: String.to_integer(value_set_at))}
  end

  @spec recommending_alert?(Route.t(), RouteStats.stats_by_route(), non_neg_integer(), any()) ::
          boolean()
  def recommending_alert?(route, stats_by_route, value_set_at, algorithm) do
    # this assumes that the algorithm function lives in the RouteStats module
    stat = apply(RouteStats, algorithm, [stats_by_route, route])
    !is_nil(stat) and stat >= value_set_at
  end
end
