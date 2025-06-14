defmodule InvisibleThreads.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    :ok = :logger.update_primary_config(%{metadata: logger_metadata()})

    children = [
      InvisibleThreadsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:invisible_threads, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: InvisibleThreads.PubSub},
      # Start a worker by calling: InvisibleThreads.Worker.start_link(arg)
      # {InvisibleThreads.Worker, arg},
      # Start to serve requests, typically the last entry
      InvisibleThreadsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: InvisibleThreads.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp logger_metadata do
    %{
      release: InvisibleThreads.release()
    }
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    InvisibleThreadsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
