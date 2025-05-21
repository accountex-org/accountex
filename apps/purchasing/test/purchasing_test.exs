defmodule PurchasingTest do
  use ExUnit.Case
  doctest Purchasing

  test "greets the world" do
    assert Purchasing.hello() == :world
  end
end
