defmodule SystemManagerTest do
  use ExUnit.Case
  doctest SystemManager

  test "greets the world" do
    assert SystemManager.hello() == :world
  end
end
