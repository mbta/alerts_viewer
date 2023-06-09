defmodule AlertsViewerWeb.BusController do
  use AlertsViewerWeb, :controller

  alias Alerts.Alert
  alias AlertsViewer.DelayAlertAlgorithm
  alias AlertsViewer.DelayAlertAlgorithm.AlgorithmComponent
  alias Routes.{Route, RouteStats, RouteStatsPubSub}

  @type delay_algorithm_snapshot_data_point :: [
          parameters: map(),
          routes_with_recommended_alerts: [Route.t()]
        ]
  @type delay_algorithm_snapshot_data :: [delay_algorithm_snapshot_data_point()]

  def snapshot(conn, %{"algorithm_module" => algorithm_module}) do
    bus_routes = Routes.all_bus_routes()
    stats_by_route = RouteStatsPubSub.all()
    bus_alerts = Alerts.all()
    routes_with_current_alerts = Enum.filter(bus_routes, &delay_alert?(&1, bus_alerts))

    algorithm_data =
      snapshot_stats(
        bus_routes,
        stats_by_route,
        String.to_existing_atom(algorithm_module)
      )

    data =
      algorithm_data
      |> Enum.map(fn [
                       parameters: parameters,
                       routes_with_recommended_alerts: routes_with_recommended_alerts
                     ] ->
        results =
          prediction_results(
            bus_routes,
            routes_with_current_alerts,
            routes_with_recommended_alerts
          )

        [
          PredictionResults.accuracy(results),
          PredictionResults.recall(results),
          PredictionResults.precision(results)
        ] ++ Map.values(parameters)
      end)

    header_row =
      [
        "Accuracy",
        "Recall",
        "Precision"
      ] ++ parameter_names(algorithm_data)

    data = [header_row | data]

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"#{csv_file_name(DelayAlertAlgorithm.humane_name(algorithm_module))}\""
    )
    |> send_resp(200, csv_content(data))
  end

  @spec snapshot_stats([Route.t()], RouteStats.stats_by_route(), atom) ::
          delay_algorithm_snapshot_data()
  def snapshot_stats(routes, stats_by_route, algorithm_module) do
    algorithm_module.min_value()..algorithm_module.max_value()//algorithm_module.interval_value()
    |> Enum.to_list()
    |> Enum.map(fn value ->
      routes_with_recommended_alerts =
        Enum.filter(
          routes,
          &AlgorithmComponent.recommending_alert?(
            &1,
            stats_by_route,
            value,
            algorithm_module.algorithm()
          )
        )

      [
        parameters:
          Map.put(
            %{},
            String.to_atom(DelayAlertAlgorithm.humane_name(algorithm_module)),
            value
          ),
        routes_with_recommended_alerts: routes_with_recommended_alerts
      ]
    end)
  end

  @spec delay_alert?(Route.t(), [Alert.t()]) :: boolean()
  defp delay_alert?(%Route{id: route_id}, alerts),
    do: Enum.any?(alerts, &Alert.matches_route_and_effect(&1, route_id, :delay))

  @spec prediction_results([Route.t()], [Route.t()], [Route.t()]) :: PredictionResults.t()
  defp prediction_results(routes, routes_with_current_alerts, routes_with_recommended_alerts) do
    predictions = Enum.map(routes, &Enum.member?(routes_with_recommended_alerts, &1))
    targets = Enum.map(routes, &Enum.member?(routes_with_current_alerts, &1))

    PredictionResults.new(predictions, targets)
  end

  defp parameter_names([data_point | _]) do
    Keyword.get(data_point, :parameters)
    |> Map.keys()
    |> Enum.map(fn key ->
      key
      |> Atom.to_string()
      |> String.capitalize()
    end)
  end

  defp parameter_names(_), do: []

  defp csv_file_name(algorithm),
    do: "#{DelayAlertAlgorithm.humane_name(algorithm)}-#{now_string()}.csv"

  defp now_string do
    "Etc/UTC"
    |> DateTime.now!()
    |> DateTime.to_iso8601()
    |> String.replace(":", "-")
  end

  @spec csv_content([[any()]]) :: String.t()
  defp csv_content(data) do
    data
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end
end
