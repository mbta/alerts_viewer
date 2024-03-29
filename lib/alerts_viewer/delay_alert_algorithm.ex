defmodule AlertsViewer.DelayAlertAlgorithm do
  @moduledoc """
  Behaviour and helper function for delay alert algorithms.
  """

  alias Routes.{Route, RouteStats}

  @type delay_algorithm_snapshot_data_point :: [
          parameters: map(),
          routes_with_recommended_alerts: [Route.t()]
        ]
  @type delay_algorithm_snapshot_data :: [delay_algorithm_snapshot_data_point()]

  @doc """
  Return a snapshot of recommended alerts across a range of parameter data.
  """
  @callback snapshot(Route.t(), RouteStats.stats_by_route()) :: delay_algorithm_snapshot_data()

  @doc """
  Provide a friendly name for an algorithm module.

  iex> DelayAlertAlgorithm.humane_name(:"Elixir.AlertsViewer.DelayAlertAlgorithm.MedianAdherenceComponent")
  "Median Adherence"
  """
  @spec humane_name(module() | String.t()) :: String.t()
  def humane_name(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> humane_name()
  end

  def humane_name(str) do
    str
    |> String.split(".")
    |> List.last()
    |> String.replace_suffix("Component", "")
    |> String.split(~r{[A-Z]}, include_captures: true, trim: true)
    |> Enum.reduce([], fn x, acc ->
      acc ++
        List.wrap(
          case String.length(x) do
            1 -> x
            _ -> x <> " "
          end
        )
    end)
    |> List.flatten()
    |> Enum.join()
    |> String.trim()
  end
end
