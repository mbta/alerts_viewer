defmodule Vehicles.Parser.SwiftlyRealtimeVehiclesTest do
  use ExUnit.Case, async: true

  import Test.Support.Helpers

  alias Vehicles.Parser.SwiftlyRealtimeVehicles
  alias Vehicles.VehiclePosition

  describe "parse/1" do
    test "parsing an enhanced VehiclePositions JSON file returns only VehiclePosition structs" do
      json = json_from_fixture("swiftly_realtime_vehicles.json")
      parsed = SwiftlyRealtimeVehicles.parse(json)
      assert is_list(parsed)

      for update <- parsed do
        assert update.__struct__ == VehiclePosition
      end
    end
  end

  describe "decode_vehicle/1" do
    test "decodes Swiftly vehicle data response JSON" do
      input = %{
        "id" => "y1714",
        "routeId" => "39",
        "routeShortName" => "39",
        "routeName" => "39 - Forest Hills - Back Bay Station",
        "headsign" => "Forest Hills",
        "vehicleType" => "3",
        "schAdhSecs" => 0,
        "schAdhStr" => "0.0 sec (ontime)",
        "previousVehicleId" => "y1272",
        "previousVehicleSchAdhSecs" => 59,
        "previousVehicleSchAdhStr" => "59.0 sec (late)",
        "blockMthd" => "AVL feed",
        "tripPattern" => "route_39_23391_to_10642_fac4a15b",
        "layover" => true,
        "layoverDepTime" => 1_559_673_780,
        "layoverDepTimeStr" => "14:43:00",
        "nextStopId" => "23391",
        "nextStopName" => "Back Bay",
        "driver" => "PAUL - 71924",
        "field1Name" => "Run",
        "field1Value" => "122-1065",
        "runId" => "122-1065",
        "serviceId" => "BUS22019-hbb29011-Weekday-02",
        "serviceName" => "BUS22019-hbb29011-Weekday-02 - Weekdays",
        "loc" => %{
          "lat" => 42.31914,
          "lon" => -71.10337,
          "time" => 1_559_672_827,
          "speed" => 11,
          "heading" => 33
        },
        "directionId" => "0",
        "tripId" => "39998535",
        "blockId" => "B36-173",
        "headwaySecs" => 2889.665,
        "scheduledHeadwaySecs" => 2340
      }

      expected =
        VehiclePosition.new(
          id: "y1714",
          bearing: 33,
          block_id: "B36-173",
          direction_id: 0,
          headsign: "Forest Hills",
          headway_secs: 2889.665,
          last_updated: 1_559_672_827,
          latitude: 42.31914,
          layover_departure_time: 1_559_673_780,
          longitude: -71.10337,
          operator_id: "71924",
          operator_last_name: "PAUL",
          previous_vehicle_id: "y1272",
          previous_vehicle_schedule_adherence_secs: 59,
          previous_vehicle_schedule_adherence_string: "59.0 sec (late)",
          route_id: "39",
          run_id: "122-1065",
          schedule_adherence_secs: 0,
          schedule_adherence_string: "0.0 sec (ontime)",
          scheduled_headway_secs: 2340,
          speed: 11,
          stop_id: "23391",
          stop_name: "Back Bay",
          trip_id: "39998535"
        )

      assert SwiftlyRealtimeVehicles.decode_vehicle(input) == expected
    end
  end
end
