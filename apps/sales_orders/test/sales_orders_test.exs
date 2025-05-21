defmodule SalesOrdersTest do
  use ExUnit.Case
  doctest SalesOrders

  test "greets the world" do
    assert SalesOrders.hello() == :world
  end
end
