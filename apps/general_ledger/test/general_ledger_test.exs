defmodule GeneralLedgerTest do
  use ExUnit.Case
  doctest GeneralLedger

  test "greets the world" do
    assert GeneralLedger.hello() == :world
  end
end
