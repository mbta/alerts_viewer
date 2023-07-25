defmodule SnapshotLogger.SnapshotLoggerTest do
  use ExUnit.Case
  import Test.Support.Helpers
  import ExUnit.CaptureLog
  alias Alerts.{Alert, AlertsPubSub, Store}
  alias Routes.{RouteStats, RouteStatsPubSub}

  @alert %Alert{
    id: "1",
    header: "Alert 1",
    effect: :delay,
    created_at: ~U[2023-07-20 10:14:20Z],
    informed_entity: [
      %{activities: [:board, :exit, :ride], route: "1", route_type: 3}
    ]
  }

  @stats_by_route %{
    "1" => %RouteStats{
      id: "1",
      vehicles_schedule_adherence_secs: [10, 20],
      vehicles_instantaneous_headway_secs: [500, 1000],
      vehicles_scheduled_headway_secs: [40, 80],
      vehicles_instantaneous_minus_scheduled_headway_secs: [460, 920]
    },
    "4" => %RouteStats{
      id: "4",
      vehicles_schedule_adherence_secs: [30]
    },
    "7" => %RouteStats{
      id: "7",
      vehicles_schedule_adherence_secs: [10, 20],
      vehicles_instantaneous_headway_secs: [500, 1000],
      vehicles_scheduled_headway_secs: [40, 80],
      vehicles_instantaneous_minus_scheduled_headway_secs: [460, 920]
    },
    "8" => %RouteStats{
      id: "8",
      vehicles_schedule_adherence_secs: [30]
    }
  }

  describe "snapshot logger" do
    setup do
      subscribe_fn = fn _, _ -> :ok end
      start_supervised({Registry, keys: :duplicate, name: :alerts_subscriptions_registry})
      {:ok, alert_pid} = AlertsPubSub.start_link(subscribe_fn: subscribe_fn)
      start_supervised({Registry, keys: :duplicate, name: :route_stats_subscriptions_registry})
      {:ok, routes_pid} = RouteStatsPubSub.start_link()

      :sys.replace_state(alert_pid, fn state ->
        store =
          Store.init()
          |> Store.add([@alert])

        Map.put(state, :store, store)
      end)

      :sys.replace_state(routes_pid, fn state ->
        Map.put(state, :stats_by_route, @stats_by_route)
      end)

      {:ok, pid} =
        SnapshotLogger.SnapshotLogger.start_link(
          name: :subscribe,
          subscribe_fn: subscribe_fn
        )

      {:ok, pid: pid}
    end

    test "it logs snapshots", %{pid: pid} do
      set_log_level(:info)

      fun = fn ->
        send(pid, :log)
        pid |> :sys.get_state()
      end

      assert capture_log(fun) =~ "[info] {\"max_adherence\""
    end
  end
end
