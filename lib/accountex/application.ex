defmodule Accountex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      AccountexWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Accountex.PubSub},
      # Start Finch
      {Finch, name: Accountex.Finch},
      # Start the Endpoint (http/https)
      AccountexWeb.Endpoint
      # Start a worker by calling: Accountex.Worker.start_link(arg)
      # {Accountex.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Accountex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AccountexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
