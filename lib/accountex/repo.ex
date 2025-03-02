defmodule Accountex.Repo do
  use Ecto.Repo,
    otp_app: :accountex,
    adapter: Ecto.Adapters.Postgres
end
