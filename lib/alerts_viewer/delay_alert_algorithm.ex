defmodule AlertsViewer.DelayAlertAlgorithm do
  @moduledoc """
  Behaviour and helper function for delay alert algorithms.
  Slider values are also used for CSV snapshot output.
  To create a new algorithm: Make a new module that implements this behavior
  (see lib/alerts_viewer_web/live/delay_alert_algorithm/median.ex) for example)
  Then add name of new module to list of delay_alert_algorithms in config.exs.
  """

  @doc """
  Returns name of function from RouteStats to be used as algorithm
  """
  @callback algorithm() :: atom

  @doc """
  Returns minimum value of value slider
  """
  @callback min_value :: integer()

  @doc """
  Returns maximum value of value slider
  """
  @callback max_value :: integer()

  @doc """
  Returns step or interval of value slider
  """
  @callback interval_value :: integer()

  @doc """
  Returns value of slider on initial load
  """
  @callback initial_value :: integer()

  @doc """
  Provide a friendly name for an algorithm module.

  iex> DelayAlertAlgorithm.humane_name(:"Elixir.AlertsViewer.DelayAlertAlgorithm.Median")
  "Median"
  iex> DelayAlertAlgorithm.humane_name("Elixir.AlertsViewer.DelayAlertAlgorithm.Median")
  "Median"
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
  end
end
