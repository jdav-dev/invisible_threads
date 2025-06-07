# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :invisible_threads, :scopes,
  user: [
    default: true,
    module: InvisibleThreads.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: InvisibleThreads.AccountsFixtures,
    test_login_helper: :register_and_log_in_user
  ]

config :invisible_threads,
  ecto_repos: [InvisibleThreads.Repo],
  generators: [timestamp_type: :utc_datetime],
  release: config_env()

# Configures the endpoint
config :invisible_threads, InvisibleThreadsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: InvisibleThreadsWeb.ErrorHTML, json: InvisibleThreadsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: InvisibleThreads.PubSub,
  live_view: [signing_salt: "BRzdapb/"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :invisible_threads, InvisibleThreads.Mailer, adapter: InvisibleThreads.LocalSwooshAdapter

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.5",
  invisible_threads: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  invisible_threads: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:release, :request_id]

# Use built-in JSON for parsing in Phoenix
config :phoenix, :json_library, JSON

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
