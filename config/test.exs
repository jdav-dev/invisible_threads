import Config

config :invisible_threads,
  postmark_req_options: [plug: {Req.Test, InvisibleThreads.Postmark}, retry: false]

config :invisible_threads,
  data_dir:
    Path.join([
      System.tmp_dir!(),
      "invisible_threads_test",
      System.get_env("MIX_TEST_PARTITION", "")
    ])

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :invisible_threads, InvisibleThreadsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "A0PRy/LUX/hiNT01E4dFZ3Nz4Kg+FEJ431S40DNES5hYegkg+ZWz394aEtY3nK0x",
  server: false

# In test we don't send emails
config :invisible_threads, InvisibleThreads.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
