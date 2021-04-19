defmodule Blu.Host do
  @moduledoc """
  TODO
  """

  @type transition_error() :: {:error, any()}

  @spec transition(Blu.action(), Blu.state()) :: {:ok, Blu.state()} | transition_error()
  def transition(_action, state) do
    {:ok, state}
  end
end
