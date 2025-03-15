defmodule Accountex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Oban,
       AshOban.config(
         Application.fetch_env!(:accountex, :ash_domains),
         Application.fetch_env!(:accountex, Oban)
       )},
      AccountexWeb.Telemetry,
      Accountex.Repo,
      {DNSCluster, query: Application.get_env(:accountex, :dns_cluster_query) || :ignore},
      {Beacon, [sites: [Application.fetch_env!(:beacon, :website)]]},
      {Phoenix.PubSub, name: Accountex.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Accountex.Finch},
      AccountexWeb.WebsiteEndpoint,
      # Start a worker by calling: Accountex.Worker.start_link(arg)
      # {Accountex.Worker, arg},
      # Start to serve requests, typically the last entry
      AccountexWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :accountex]},
      AccountexWeb.ProxyEndpoint
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
