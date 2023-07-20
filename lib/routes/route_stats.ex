defmodule Routes.RouteStats do
  @moduledoc """
  Describe a collection of stats for the current state of a route.
  """

  alias Routes.Route
  alias Vehicles.Vehicle

  defstruct [
    :id,
    vehicles_schedule_adherence_secs: [],
    vehicles_instantaneous_headway_secs: [],
    vehicles_scheduled_headway_secs: [],
    vehicles_instantaneous_minus_scheduled_headway_secs: []
  ]

  @type t :: %__MODULE__{
          id: Route.id(),
          vehicles_schedule_adherence_secs: [integer()],
          vehicles_instantaneous_headway_secs: [integer() | nil],
          vehicles_scheduled_headway_secs: [integer() | nil],
          vehicles_instantaneous_minus_scheduled_headway_secs: [integer() | nil]
        }

  @type stats_by_route() :: %{Route.id() => t()}

  @spec from_vehicles(Route.id(), [Vehicle.t()]) :: t()
  def from_vehicles(route_id, vehicles) do
    %__MODULE__{
      id: route_id,
      vehicles_schedule_adherence_secs: schedule_adherence_secs_of_vehicles(vehicles),
      vehicles_instantaneous_headway_secs: instantaneous_headway_secs_of_vehicles(vehicles),
      vehicles_scheduled_headway_secs: scheduled_headway_secs_of_vehicles(vehicles),
      vehicles_instantaneous_minus_scheduled_headway_secs:
        instantaneous_minus_scheduled_headway_secs_of_vehicles(vehicles)
    }
  end

  @spec vehicles_schedule_adherence_secs(t()) :: [integer()]
  @spec vehicles_schedule_adherence_secs(stats_by_route(), Route.t()) :: [integer()]
  def vehicles_schedule_adherence_secs(%__MODULE__{
        vehicles_schedule_adherence_secs: vehicles_schedule_adherence_secs
      }),
      do: vehicles_schedule_adherence_secs

  def vehicles_schedule_adherence_secs(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> vehicles_schedule_adherence_secs()
  end

  @spec vehicles_instantaneous_headway_secs(t()) :: [integer()]
  @spec vehicles_instantaneous_headway_secs(stats_by_route(), Route.t()) :: [integer()]
  def vehicles_instantaneous_headway_secs(%__MODULE__{
        vehicles_instantaneous_headway_secs: vehicles_instantaneous_headway_secs
      }),
      do: vehicles_instantaneous_headway_secs

  def vehicles_instantaneous_headway_secs(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> vehicles_instantaneous_headway_secs()
  end

  @spec vehicles_scheduled_headway_secs(t()) :: [integer()]
  @spec vehicles_scheduled_headway_secs(stats_by_route(), Route.t()) :: [integer()]
  def vehicles_scheduled_headway_secs(%__MODULE__{
        vehicles_scheduled_headway_secs: vehicles_scheduled_headway_secs
      }),
      do: vehicles_scheduled_headway_secs

  def vehicles_scheduled_headway_secs(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> vehicles_scheduled_headway_secs()
  end

  @spec vehicles_instantaneous_minus_scheduled_headway_secs(t()) :: [integer()]
  @spec vehicles_instantaneous_minus_scheduled_headway_secs(stats_by_route(), Route.t()) :: [
          integer()
        ]
  def vehicles_instantaneous_minus_scheduled_headway_secs(%__MODULE__{
        vehicles_instantaneous_minus_scheduled_headway_secs:
          vehicles_instantaneous_minus_scheduled_headway_secs
      }),
      do: vehicles_instantaneous_minus_scheduled_headway_secs

  def vehicles_instantaneous_minus_scheduled_headway_secs(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> vehicles_instantaneous_minus_scheduled_headway_secs()
  end

  ############# Algorithms for Schedule Adherence
  @spec max_schedule_adherence(t()) :: number() | nil
  @spec max_schedule_adherence(stats_by_route(), Route.t()) :: number() | nil
  def max_schedule_adherence(route_stats) do
    route_stats
    |> vehicles_schedule_adherence_secs()
    |> Enum.max(fn -> nil end)
  end

  def max_schedule_adherence(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> max_schedule_adherence()
  end

  @spec median_schedule_adherence(t()) :: number() | nil
  @spec median_schedule_adherence(stats_by_route(), Route.t()) :: number() | nil
  def median_schedule_adherence(route_stats) do
    route_stats
    |> vehicles_schedule_adherence_secs()
    |> Statistics.median()
    |> round_to_1_place()
  end

  def median_schedule_adherence(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> median_schedule_adherence()
  end

  @spec standard_deviation_of_schedule_adherence(t()) ::
          number() | nil
  @spec standard_deviation_of_schedule_adherence(stats_by_route(), Route.t()) ::
          number() | nil
  def standard_deviation_of_schedule_adherence(route_stats) do
    route_stats
    |> vehicles_schedule_adherence_secs()
    |> Statistics.stdev()
    |> round_to_1_place()
  end

  def standard_deviation_of_schedule_adherence(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> standard_deviation_of_schedule_adherence()
  end

  ########### Algorithms for Instantaneous_headway
  @spec median_instantaneous_headway(t()) :: number() | nil
  @spec median_instantaneous_headway(stats_by_route(), Route.t()) :: number() | nil
  def median_instantaneous_headway(route_stats) do
    route_stats
    |> vehicles_instantaneous_headway_secs()
    |> Statistics.median()
    |> round_to_1_place()
  end

  def median_instantaneous_headway(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> median_instantaneous_headway()
  end

  @spec standard_deviation_of_instantaneous_headway(t()) ::
          number() | nil
  @spec standard_deviation_of_instantaneous_headway(stats_by_route(), Route.t()) ::
          number() | nil
  def standard_deviation_of_instantaneous_headway(route_stats) do
    route_stats
    |> vehicles_instantaneous_headway_secs()
    |> Statistics.stdev()
    |> round_to_1_place()
  end

  def standard_deviation_of_instantaneous_headway(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> standard_deviation_of_instantaneous_headway()
  end

  #########  Algorithms for Scheduled Headway
  @spec median_scheduled_headway(t()) :: number() | nil
  @spec median_scheduled_headway(stats_by_route(), Route.t()) :: number() | nil
  def median_scheduled_headway(route_stats) do
    route_stats
    |> vehicles_scheduled_headway_secs()
    |> Statistics.median()
    |> round_to_1_place()
  end

  def median_scheduled_headway(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> median_scheduled_headway()
  end

  @spec standard_deviation_of_scheduled_headway(t()) ::
          number() | nil
  @spec standard_deviation_of_scheduled_headway(stats_by_route(), Route.t()) ::
          number() | nil
  def standard_deviation_of_scheduled_headway(route_stats) do
    route_stats
    |> vehicles_scheduled_headway_secs()
    |> Statistics.stdev()
    |> round_to_1_place()
  end

  def standard_deviation_of_scheduled_headway(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> standard_deviation_of_scheduled_headway()
  end

  ####### Algorithms for Instantaneous Minus Scheduled Headway
  @spec median_instantaneous_minus_scheduled_headway(t()) :: number() | nil
  @spec median_instantaneous_minus_scheduled_headway(stats_by_route(), Route.t()) ::
          number() | nil
  def median_instantaneous_minus_scheduled_headway(route_stats) do
    route_stats
    |> vehicles_instantaneous_minus_scheduled_headway_secs()
    |> Statistics.median()
    |> round_to_1_place()
  end

  def median_instantaneous_minus_scheduled_headway(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> median_instantaneous_minus_scheduled_headway()
  end

  @spec standard_deviation_of_instantaneous_minus_scheduled_headway(t()) ::
          number() | nil
  @spec standard_deviation_of_instantaneous_minus_scheduled_headway(stats_by_route(), Route.t()) ::
          number() | nil
  def standard_deviation_of_instantaneous_minus_scheduled_headway(route_stats) do
    route_stats
    |> vehicles_instantaneous_minus_scheduled_headway_secs()
    |> Statistics.stdev()
    |> round_to_1_place()
  end

  def standard_deviation_of_instantaneous_minus_scheduled_headway(stats_by_route, route) do
    stats_by_route
    |> stats_for_route(route)
    |> standard_deviation_of_instantaneous_minus_scheduled_headway()
  end

  ################ Functions to get stats per vehicle
  @spec stats_for_route(stats_by_route(), Route.t()) :: t()
  def stats_for_route(stats_by_route, %Route{id: route_id}),
    do: Map.get(stats_by_route, route_id, %__MODULE__{})

  @spec schedule_adherence_secs_of_vehicles([Vehicle.t()]) :: [integer()]
  defp schedule_adherence_secs_of_vehicles(vehicles) do
    map_and_remove_nils(vehicles, &Vehicle.schedule_adherence_secs/1)
  end

  @spec instantaneous_headway_secs_of_vehicles([Vehicle.t()]) :: [integer()]
  defp instantaneous_headway_secs_of_vehicles(vehicles) do
    map_and_remove_nils(vehicles, &Vehicle.instantaneous_headway_secs/1)
  end

  @spec scheduled_headway_secs_of_vehicles([Vehicle.t()]) :: [integer()]
  defp scheduled_headway_secs_of_vehicles(vehicles) do
    map_and_remove_nils(vehicles, &Vehicle.scheduled_headway_secs/1)
  end

  @spec instantaneous_minus_scheduled_headway_secs_of_vehicles([Vehicle.t()]) :: [integer()]
  defp instantaneous_minus_scheduled_headway_secs_of_vehicles(vehicles) do
    Enum.reject(
      vehicles,
      &(is_nil(Vehicle.scheduled_headway_secs(&1)) or
          is_nil(Vehicle.instantaneous_headway_secs(&1)))
    )
    |> Enum.reduce([], fn vehicle, acc ->
      scheduled_secs = Vehicle.scheduled_headway_secs(vehicle)
      instantaneous_secs = Vehicle.instantaneous_headway_secs(vehicle)

      [instantaneous_secs - scheduled_secs | acc]
    end)
    |> Enum.reverse()
  end

  defp map_and_remove_nils(vehicles, function) do
    Enum.map(vehicles, &function.(&1))
    |> Enum.reject(&is_nil(&1))
  end

  @spec round_to_1_place(number() | nil) :: number() | nil
  defp round_to_1_place(int) when is_integer(int), do: int
  defp round_to_1_place(num) when is_number(num), do: Float.round(num, 1)
  defp round_to_1_place(_), do: nil
end
