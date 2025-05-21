defmodule InventoryControlTest do
  use ExUnit.Case
  doctest InventoryControl

  test "greets the world" do
    assert InventoryControl.hello() == :world
  end
end
