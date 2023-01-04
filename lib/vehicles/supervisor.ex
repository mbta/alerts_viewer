defmodule Vehicles.Supervisor do
  @moduledoc """
  Supervisor for realtime Vehicle data. Fetches vehicle position data from Swiftly.
  """
  use Supervisor

  def start_link(opts) do
    source =
      Supervisor.child_spec(
        {
          HttpProducer,
          {opts[:swiftly_realtime_vehicles_url],
           [name: :swiftly_realtime_vehicles, parser: Concentrate.Parser.SwiftlyRealtimeVehicles] ++
             [
               headers: %{
                 "Authorization" => opts[:swiftly_authorization_key]
               },
               params: %{
                 unassigned: "true",
                 verbose: "true"
               }
             ]}
        },
        id: :swiftly_realtime_vehicles
      )

    # Supervisor.start_link(__MODULE__, :ok)
  end
end
