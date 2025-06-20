defmodule Test.Support.Helpers do
  @moduledoc """
  Test helpers
  """

  defmacro reassign_env(app, var, value) do
    quote do
      old_value = Application.get_env(unquote(app), unquote(var))
      Application.put_env(unquote(app), unquote(var), unquote(value))

      on_exit(fn ->
        if old_value == nil do
          Application.delete_env(unquote(app), unquote(var))
        else
          Application.put_env(unquote(app), unquote(var), old_value)
        end
      end)
    end
  end

  defmacro set_log_level(log_level) do
    quote do
      old_log_level = Logger.level()

      on_exit(fn ->
        Logger.configure(level: old_log_level)
      end)

      Logger.configure(level: unquote(log_level))
    end
  end

  def json_from_fixture(filename) do
    filename
    |> fixture_path()
    |> File.read!()
    |> Jason.decode!(strings: :copy)
  end

  def fixture_path(path) do
    fixture_path = Path.expand("./fixtures", __DIR__)
    Path.expand(path, fixture_path)
  end
end
