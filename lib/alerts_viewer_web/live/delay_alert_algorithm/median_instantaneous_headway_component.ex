defmodule AlertsViewer.DelayAlertAlgorithm.MedianInstantaneousHeadwayComponent do
  use AlertsViewer.DelayAlertAlgorithm.OneSliderComponent

  @moduledoc """
  Component for controlling the Median delay alert recommendation algorithm.
  """

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex space-x-16 items-center">
      <.controls_form phx-change="update-controls" phx-target={@myself}>
        <.input
          type="range"
          name="min_value"
          value={@min_value}
          min={snapshot_min()}
          max={snapshot_max()}
          label="Minumum Median Instantaneous Headway"
        />
        <span class="ml-2">
          <%= @min_value %>
        </span>
      </.controls_form>
      <%= snapshot_button(assigns) %>
    </div>
    """
  end

  def snapshot_button(assigns) do
    ~H"""
    <.link
      navigate={~p"/bus/snapshot/#{__MODULE__}"}
      replace={false}
      target="_blank"
      class="bg-transparent hover:bg-zinc-500 text-zinc-700 font-semibold hover:text-white py-2 px-4 border border-zinc-500 hover:border-transparent hover:no-underline rounded"
    >
      Snapshot
    </.link>
    """
  end

  @spec recommending_alert?(Route.t(), RouteStats.stats_by_route(), non_neg_integer()) ::
          boolean()
  defp recommending_alert?(route, stats_by_route, min_value) do
    median = RouteStats.median_instantaneous_headway(stats_by_route, route)
    !is_nil(median) and median >= min_value
  end
end
