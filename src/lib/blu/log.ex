defmodule Blu.Log do
  @moduledoc """
  Provides macros that simplify standardized structured logging.
  """

  defmacro __using__(_opts) do
    quote do
      import Blu.Log
      require Logger
    end
  end

  defmacro debug(structured_data) do
    quote bind_quoted: [structured_data: structured_data] do
      __MODULE__
      |> Blu.Log.transform_log(structured_data)
      |> Logger.debug()
    end
  end

  defmacro warn(structured_data) do
    quote bind_quoted: [structured_data: structured_data] do
      __MODULE__
      |> Blu.Log.transform_log(structured_data)
      |> Logger.warn()
    end
  end

  defmacro error(structured_data) do
    quote bind_quoted: [structured_data: structured_data] do
      __MODULE__
      |> Blu.Log.transform_log(structured_data)
      |> Logger.error()
    end
  end

  defmacro info(structured_data) do
    quote bind_quoted: [structured_data: structured_data] do
      __MODULE__
      |> Blu.Log.transform_log(structured_data)
      |> Logger.info()
    end
  end

  @doc false
  def transform_log(module, structured_data) when is_map(structured_data) do
    %{}
    |> Map.put(:module, module)
    |> Map.put(:data, structured_data)
    |> Jason.encode!()
  end
end
