defmodule Blu.Transports.Behaviour do
  @moduledoc """
  TODO
  """

  @typedoc "See `t:setup_opts`."
  @type setup_opt() :: {:id, Blu.id()}

  @typedoc """
  ## Options

  `:id` - `atom()`. Required.
  """
  @type setup_opts() :: [setup_opt()]

  @callback setup(setup_opts()) :: {:ok, pid()}
  @callback write(Blu.id(), binary()) :: :ok | {:error, any()}
end
