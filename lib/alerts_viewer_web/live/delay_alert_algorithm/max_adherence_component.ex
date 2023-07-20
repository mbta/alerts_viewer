defmodule AlertsViewer.DelayAlertAlgorithm.MaxAdherenceComponent do
  @moduledoc """
  Component for controlling the Max adherence delay alert recommendation algorithm.
  """

  @snapshot_min 0
  @snapshot_max 100
  @snapshot_interval 5
  @default_min_value 15

  use AlertsViewer.DelayAlertAlgorithm.BaseAlgorithmComponents.OneSliderComponent,
    snapshot_min: @snapshot_min,
    snapshot_max: @snapshot_max,
    snapshot_interval: @snapshot_interval,
    min_value: @default_min_value

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex space-x-16 items-center">
      <.controls_form phx-change="update-controls" phx-target={@myself}>
        <.input
          type="range"
          name="min_value"
          value={@min_value}
          min={0}
          max={100}
          label="Threshold (minutes)"
        />
        <span class="ml-2">
          <%= @min_value %>
        </span>
      </.controls_form>
      <SnapshotButtonComponent.snapshot_button module_name={__MODULE__} />
    </div>
    """
  end

  @impl true
  def snapshot(routes, stats_by_route) do
    @snapshot_min..@snapshot_max//@snapshot_interval
    |> Enum.to_list()
    |> Enum.map(fn value ->
      routes_with_recommended_alerts =
        Enum.filter(
          routes,
          &recommending_alert?(&1, stats_by_route, value)
        )

      [
        parameters: %{value: value},
        routes_with_recommended_alerts: routes_with_recommended_alerts
      ]
    end)
  end

  @spec recommending_alert?(Route.t(), RouteStats.stats_by_route(), non_neg_integer()) ::
          boolean()
  defp recommending_alert?(route, stats_by_route, threshold_in_minutes) do
    max = RouteStats.max_schedule_adherence(stats_by_route, route)
    !is_nil(max) and max >= threshold_in_minutes * 60
  end
end
