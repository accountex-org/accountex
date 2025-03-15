defmodule Accountex.System.ActivitySetup do
  use Ash.Resource,
    otp_app: :accountex,
    domain: Accountex.System,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "activity_setups"
    repo Accountex.Repo
  end
end
