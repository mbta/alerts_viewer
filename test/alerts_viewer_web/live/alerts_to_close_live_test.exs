defmodule AlertsViewerWeb.AlertsToCloseLiveTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  use AlertsViewerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias Alerts.{Alert, AlertsPubSub, Store}
  alias Routes.{RouteStats, RouteStatsPubSub}
  alias TripUpdates.TripUpdatesPubSub

  @alerts [
    _too_short = %Alert{
      id: "1",
      header: "Alert 1",
      effect: :delay,
      created_at: DateTime.now!("America/New_York") |> DateTime.add(-59, :minute),
      informed_entity: [
        %{activities: [:board, :exit, :ride], route: "1", route_type: 3}
      ]
    },
    _peak_too_high = %Alert{
      id: "4",
      header: "Alert 2",
      effect: :delay,
      created_at: DateTime.now!("America/New_York") |> DateTime.add(-2, :hour),
      informed_entity: [
        %{activities: [:board, :exit, :ride], route: "4", route_type: 3}
      ]
    },
    _just_right = %Alert{
      id: "5",
      header: "Alert 2",
      effect: :delay,
      created_at: DateTime.now!("America/New_York") |> DateTime.add(-2, :hour),
      informed_entity: [
        %{activities: [:board, :exit, :ride], route: "5", route_type: 3}
      ]
    },
    _no_headways = %Alert{
      id: "7",
      header: "Alert 2",
      effect: :delay,
      created_at: DateTime.now!("America/New_York") |> DateTime.add(-2, :hour),
      informed_entity: [
        %{activities: [:board, :exit, :ride], route: "7", route_type: 3}
      ]
    }
  ]

  @stats_by_route %{
    "1" => %RouteStats{
      id: "1",
      vehicles_schedule_adherence_secs: [100, 200],
      vehicles_instantaneous_headway_secs: [500, 1000],
      vehicles_scheduled_headway_secs: [40, 80],
      vehicles_headway_deviation_secs: [460, 920]
    },
    "4" => %RouteStats{
      id: "4",
      vehicles_schedule_adherence_secs: [400, 500],
      vehicles_instantaneous_headway_secs: [1500, 2000],
      vehicles_scheduled_headway_secs: [400, 880],
      vehicles_headway_deviation_secs: [1100, 1120]
    },
    "5" => %RouteStats{
      id: "5",
      vehicles_schedule_adherence_secs: [100, 200],
      vehicles_instantaneous_headway_secs: [500, 1000],
      vehicles_scheduled_headway_secs: [40, 80],
      vehicles_headway_deviation_secs: [460, 920]
    }
  }

  @block_waivered_routes ["4"]

  describe "bus live page" do
    setup do
      start_supervised({Registry, keys: :duplicate, name: :alerts_subscriptions_registry})
      subscribe_fn = fn _, _ -> :ok end
      {:ok, alert_pid} = AlertsPubSub.start_link(subscribe_fn: subscribe_fn)
      start_supervised({Registry, keys: :duplicate, name: :route_stats_subscriptions_registry})
      {:ok, routes_pid} = RouteStatsPubSub.start_link()
      start_supervised({Registry, keys: :duplicate, name: :trip_updates_subscriptions_registry})
      {:ok, update_pid} = TripUpdatesPubSub.start_link()

      :sys.replace_state(alert_pid, fn state ->
        store =
          Store.init()
          |> Store.add(@alerts)

        Map.put(state, :store, store)
      end)

      :sys.replace_state(routes_pid, fn state ->
        Map.put(state, :stats_by_route, @stats_by_route)
      end)

      :sys.replace_state(update_pid, fn state ->
        Map.put(state, :block_waivered_routes, @block_waivered_routes)
      end)

      reassign_env(:alerts_viewer, :api_url, "http://localhost:#{54_292}")

      {:ok, %{}}
    end

    test "connected mount", %{conn: conn} do
      use_cassette "routes", custom: true, clear_mock: true, match_requests_on: [:query] do
        {:ok, _view, html} = live(conn, "/alerts-to-close")
        assert html =~ ~r/Alerts/
        assert html =~ ~r/Cool Bus Route/
        assert html =~ ~r/Cooler Bus Route/
      end
    end
  end

  describe "recommended_closures" do
    test "recommends correct routes for closure" do
      [recommended_closure] =
        AlertsViewerWeb.AlertsToCloseLive.recommended_closures(@alerts, @stats_by_route)

      assert recommended_closure.id == "5"
    end
  end

  describe "Laboratory flags" do
    setup do
      start_supervised({Registry, keys: :duplicate, name: :alerts_subscriptions_registry})
      {:ok, _pid} = AlertsPubSub.start_link(subscribe_fn: fn _, _ -> :ok end)
      start_supervised({Registry, keys: :duplicate, name: :route_stats_subscriptions_registry})
      {:ok, _pid} = RouteStatsPubSub.start_link()
      start_supervised({Registry, keys: :duplicate, name: :trip_updates_subscriptions_registry})
      {:ok, _pid} = TripUpdatesPubSub.start_link()
      reassign_env(:alerts_viewer, :api_url, "http://localhost:#{54_292}")

      {:ok, %{}}
    end

    test "Extra links not shown if internal_pages flag is not set", %{conn: conn} do
      use_cassette "routes", custom: true, clear_mock: true, match_requests_on: [:query] do
        {:ok, _view, html} = live(conn, "/alerts-to-close")
        refute html =~ ~r/a href="\/alerts"/
      end
    end

    test "Extra links shown if internal_pages flag is set", %{conn: conn} do
      use_cassette "routes", custom: true, clear_mock: true, match_requests_on: [:query] do
        conn = conn |> put_resp_cookie("show_internal_pages_flag", "true")
        {:ok, _view, html} = live(conn, "/alerts-to-close")
        assert html =~ ~r/a href="\/alerts"/
      end
    end
  end
end
