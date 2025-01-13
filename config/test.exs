import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ocrlot, OcrlotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "k0KYJMH2H77mc/Fwwp1dnmlDegJE0/1GQC6DS0VKuE1KDm5L9fKezAS+U6kZTwG7",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
