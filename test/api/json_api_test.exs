defmodule Api.JsonApiTest do
  use ExUnit.Case, async: true

  alias Api.JsonApi
  alias Api.JsonApi.{Error, Item}

  describe "empty/0" do
    test "returns a JsonApi struct with no data" do
      assert JsonApi.empty() == %JsonApi{data: []}
    end
  end

  describe "parse/1" do
    test ".parse parses an error into a JsonApi.Error struct" do
      body = """
      {
        "jsonapi": {"version": "1.0"},
        "errors": [
          {
            "code": "code",
            "detail": "detail",
            "source": {
              "parameter": "name"
            },
            "meta": {
              "key": "value"
            }
          }
        ]
      }
      """

      parsed = JsonApi.parse(body)

      assert {:error,
              [
                %Error{
                  code: "code",
                  detail: "detail",
                  source: %{"parameter" => "name"},
                  meta: %{"key" => "value"}
                }
              ]} = parsed
    end

    test ".parse parses invalid JSON into an error tuple" do
      assert {:error, _} = JsonApi.parse("invalid")
    end

    test ".parses valid JSON without data or errors into an invalid error tuple" do
      assert {:error, :invalid} =
               JsonApi.parse("""
               {
                 "jsonapi": {"version": "1.0"}
               }
               """)
    end

    test ".parse parses a body into a JsonApi struct" do
      body = """
      {"jsonapi":{"version":"1.0"},"included":[{"type":"stop","id":"place-harsq","attributes":{"wheelchair_boarding":1,"name":"Harvard","longitude":-71.118956,"latitude":42.373362}}],"data":{"type":"stop","relationships":{"parent_station":{"data":{"type":"stop","id":"place-harsq"}}},"links":{"self":"/stops/20761"},"id":"20761","attributes":{"wheelchair_boarding":0,"name":"Harvard Upper Busway @ Red Line","longitude":-71.118956,"latitude":42.373362}}}
      """

      assert JsonApi.parse(body) ==
               {:ok,
                %JsonApi{
                  data: [
                    %Item{
                      type: "stop",
                      id: "20761",
                      attributes: %{
                        "name" => "Harvard Upper Busway @ Red Line",
                        "wheelchair_boarding" => 0,
                        "latitude" => 42.373362,
                        "longitude" => -71.118956
                      },
                      relationships: %{
                        "parent_station" => [
                          %Item{
                            type: "stop",
                            id: "place-harsq",
                            attributes: %{
                              "name" => "Harvard",
                              "wheelchair_boarding" => 1,
                              "latitude" => 42.373362,
                              "longitude" => -71.118956
                            },
                            relationships: %{}
                          }
                        ]
                      }
                    }
                  ]
                }}
    end

    test ".parse parses a relationship that's present in data" do
      body = """
      {"jsonapi":{"version":"1.0"},"data":[{"type":"stop","relationships":{"parent_station":{"data":{"type":"stop","id":"place-harsq"}}},"links":{"self":"/stops/20761"},"id":"20761","attributes":{"wheelchair_boarding":0,"name":"Harvard Upper Busway @ Red Line","longitude":-71.118956,"latitude":42.373362}},{"type":"stop","id":"place-harsq","attributes":{"wheelchair_boarding":1,"name":"Harvard","longitude":-71.118956,"latitude":42.373362}}]}
      """

      assert JsonApi.parse(body) ==
               {:ok,
                %JsonApi{
                  data: [
                    %Item{
                      type: "stop",
                      id: "20761",
                      attributes: %{
                        "name" => "Harvard Upper Busway @ Red Line",
                        "wheelchair_boarding" => 0,
                        "latitude" => 42.373362,
                        "longitude" => -71.118956
                      },
                      relationships: %{
                        "parent_station" => [
                          %Item{
                            type: "stop",
                            id: "place-harsq",
                            attributes: %{
                              "name" => "Harvard",
                              "wheelchair_boarding" => 1,
                              "latitude" => 42.373362,
                              "longitude" => -71.118956
                            },
                            relationships: %{}
                          }
                        ]
                      }
                    },
                    %Item{
                      type: "stop",
                      id: "place-harsq",
                      attributes: %{
                        "name" => "Harvard",
                        "wheelchair_boarding" => 1,
                        "latitude" => 42.373362,
                        "longitude" => -71.118956
                      },
                      relationships: %{}
                    }
                  ]
                }}
    end

    test ".parse handles a non-included relationship" do
      body = """
      {"jsonapi":{"version":"1.0"},"data":{"type":"stop","relationships":{"other":{"data":{"type":"other","id":"1"}}},"links":{},"id":"20761","attributes":{}}}
      """

      assert JsonApi.parse(body) ==
               {:ok,
                %JsonApi{
                  data: [
                    %Item{
                      type: "stop",
                      id: "20761",
                      attributes: %{},
                      relationships: %{
                        "other" => [%Item{type: "other", id: "1"}]
                      }
                    }
                  ]
                }}
    end

    @tag timeout: 5000
    test ".parse handles a cyclical included relationship with properties" do
      {:ok, body} =
        Jason.encode(%{
          data: %{
            attributes: %{},
            id: "Worcester",
            relationships: %{
              facilities: %{
                data: [
                  %{
                    id: "subplat-056",
                    type: "facility"
                  }
                ]
              }
            },
            type: "stop"
          },
          included: [
            %{
              attributes: %{},
              id: "subplat-056",
              relationships: %{
                stop: %{
                  data: %{
                    id: "Worcester",
                    type: "stop"
                  }
                }
              },
              type: "facility"
            }
          ],
          jsonapi: %{version: "1.0"}
        })

      assert JsonApi.parse(body) ==
               {:ok,
                %JsonApi{
                  data: [
                    %Item{
                      type: "stop",
                      id: "Worcester",
                      attributes: %{},
                      relationships: %{
                        "facilities" => [
                          %Item{
                            type: "facility",
                            id: "subplat-056",
                            attributes: %{},
                            relationships: %{
                              "stop" => [
                                %Item{
                                  type: "stop",
                                  id: "Worcester",
                                  attributes: %{},
                                  relationships: %{}
                                }
                              ]
                            }
                          }
                        ]
                      }
                    }
                  ]
                }}
    end

    test ".parse handles an empty relationship" do
      body = """
      {"jsonapi":{"version":"1.0"},"data":{"type":"stop","relationships":{"parent_station":{},"other":{"data": null}},"links":{},"id":"20761","attributes":{}}}
      """

      assert JsonApi.parse(body) ==
               {:ok,
                %JsonApi{
                  data: [
                    %Item{
                      type: "stop",
                      id: "20761",
                      attributes: %{},
                      relationships: %{
                        "parent_station" => [],
                        "other" => []
                      }
                    }
                  ]
                }}
    end

    test ".parse handles ServerSentEventStream data format" do
      list = ~s([{"type":"stop","links":{},"id":"20761","attributes":{}}])

      assert JsonApi.parse(list) ==
               {:ok,
                %JsonApi{
                  data: [
                    %Item{id: "20761", type: "stop", attributes: %{}, relationships: %{}}
                  ]
                }}

      item = ~s({"type":"stop","links":{},"id":"20761","attributes":{}})

      assert JsonApi.parse(item) ==
               {:ok,
                %JsonApi{
                  data: [
                    %Item{id: "20761", type: "stop", attributes: %{}, relationships: %{}}
                  ]
                }}
    end
  end

  describe "merge/2" do
    test "merged item contains all data" do
      first = %JsonApi{
        data: ["a"]
      }

      second = %JsonApi{
        data: ["b"]
      }

      expected = %JsonApi{
        data: ["a", "b"]
      }

      assert JsonApi.merge(first, second) == expected
    end
  end
end
