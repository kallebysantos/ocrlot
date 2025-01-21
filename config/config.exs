# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ocrlot,
  generators: [timestamp_type: :utc_datetime],
  # Each worker can take ~120Mib
  extractor_max_workers: String.to_integer(System.get_env("EXTRACTOR_MAX_WORKERS") || "3")

# Configures the endpoint
config :ocrlot, OcrlotWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: OcrlotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Ocrlot.PubSub,
  live_view: [signing_salt: "cFnCLvKc"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
