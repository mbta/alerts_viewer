defmodule AlertsViewer.DelayAlertAlgorithm.Median do
  @moduledoc """
  Component for controlling the Median delay alert recommendation algorithm.
  """

  @behaviour AlertsViewer.DelayAlertAlgorithm

  @median_min 50
  @median_max 1500
  @median_interval 50
  @median_initial_value 1200
  @median_algorithm :median_schedule_adherence

  @impl true
  @spec algorithm :: :median_schedule_adherence
  def algorithm, do: @median_algorithm

  @impl true
  def min_value, do: @median_min

  @impl true
  def max_value, do: @median_max

  @impl true
  def interval_value, do: @median_interval

  @impl true
  def initial_value, do: @median_initial_value
end
