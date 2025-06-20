defmodule Vehicles.Parser.SwiftlyRealtimeVehicles do
  @moduledoc """
  Parser for Swiftly Real-time Vehicles API response.

  Documentation:
  https://realtime-docs.goswift.ly/api-reference/real-time/getrealtimeagencykeyvehicles
  """

  alias Vehicles.VehiclePosition

  def parse(json), do: decode_response(json)

  @spec decode_response(map()) :: [VehiclePosition.t()]
  defp decode_response(%{"data" => %{"vehicles" => vehicles}}), do: decode_vehicles(vehicles)

  @spec decode_vehicles([map()]) :: [VehiclePosition.t()]
  defp decode_vehicles(vehicles), do: Enum.map(vehicles, &decode_vehicle/1)

  @spec decode_vehicle(map()) :: VehiclePosition.t()
  def decode_vehicle(vehicle_data) do
    loc = Map.get(vehicle_data, "loc", %{})
    {operator_last_name, operator_id} = vehicle_data |> Map.get("driver") |> operator_details()

    last_updated = Map.get(loc, "time")

    VehiclePosition.new(
      id: Map.get(vehicle_data, "id"),
      bearing: Map.get(loc, "heading"),
      block_id: Map.get(vehicle_data, "blockId"),
      direction_id: vehicle_data |> Map.get("directionId") |> direction_id_from_string(),
      headsign: Map.get(vehicle_data, "headsign"),
      headway_secs: Map.get(vehicle_data, "headwaySecs"),
      last_updated: last_updated,
      latitude: Map.get(loc, "lat"),
      layover_departure_time: Map.get(vehicle_data, "layoverDepTime"),
      longitude: Map.get(loc, "lon"),
      operator_id: operator_id,
      operator_last_name: operator_last_name,
      previous_vehicle_id: Map.get(vehicle_data, "previousVehicleId"),
      previous_vehicle_schedule_adherence_secs:
        Map.get(vehicle_data, "previousVehicleSchAdhSecs"),
      previous_vehicle_schedule_adherence_string:
        Map.get(vehicle_data, "previousVehicleSchAdhStr"),
      route_id: Map.get(vehicle_data, "routeId"),
      run_id: Map.get(vehicle_data, "runId"),
      schedule_adherence_secs: Map.get(vehicle_data, "schAdhSecs"),
      schedule_adherence_string: Map.get(vehicle_data, "schAdhStr"),
      scheduled_headway_secs: Map.get(vehicle_data, "scheduledHeadwaySecs"),
      speed: Map.get(loc, "speed"),
      stop_id: Map.get(vehicle_data, "nextStopId"),
      stop_name: Map.get(vehicle_data, "nextStopName"),
      trip_id: Map.get(vehicle_data, "tripId")
    )
  end

  @spec operator_details(String.t() | nil) :: {String.t() | nil, String.t() | nil}
  defp operator_details(nil), do: {nil, nil}

  defp operator_details(operator_string) do
    case String.split(operator_string, " - ") do
      [operator_last_name, operator_id] -> {operator_last_name, operator_id}
      _ -> {nil, nil}
    end
  end

  @spec direction_id_from_string(String.t() | nil) :: VehiclePosition.direction_id() | nil
  def direction_id_from_string("0"), do: 0
  def direction_id_from_string("1"), do: 1
  def direction_id_from_string(_), do: nil
end
