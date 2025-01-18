defmodule Ocrlot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OcrlotWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:ocrlot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Ocrlot.PubSub},
      # Start a worker by calling: Ocrlot.Worker.start_link(arg)
      # {Ocrlot.Worker, arg},
      # Start to serve requests, typically the last entry
      OcrlotWeb.Endpoint,
      {Task.Supervisor, name: Ocrlot.Converter.TaskSupervisor, strategy: :one_for_one},
      Ocrlot.ExtractorWorkerPool
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ocrlot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OcrlotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
