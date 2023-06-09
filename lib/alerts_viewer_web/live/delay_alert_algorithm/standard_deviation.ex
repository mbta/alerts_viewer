defmodule AlertsViewer.DelayAlertAlgorithm.StandardDeviation do
  @moduledoc """
  Component for controlling the standard deviation delay alert recommendation algorithm.
  """
  @behaviour AlertsViewer.DelayAlertAlgorithm

  @standard_deviation_min 50
  @standard_deviation_initial_value 1200
  @standard_deviation_max 1500
  @standard_deviation_interval 50
  @standard_deviation_algorithm :standard_deviation_of_schedule_adherence

  @impl true
  @spec algorithm :: :standard_deviation_of_schedule_adherence
  def algorithm, do: @standard_deviation_algorithm

  @impl true
  def min_value, do: @standard_deviation_min

  @impl true
  def max_value, do: @standard_deviation_max

  @impl true
  def interval_value, do: @standard_deviation_interval

  @impl true
  def initial_value, do: @standard_deviation_initial_value
end
