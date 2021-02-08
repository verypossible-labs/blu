defmodule BluTest do
  use ExUnit.Case
  doctest Blu

  test "greets the world" do
    assert Blu.hello() == :world
  end
end
