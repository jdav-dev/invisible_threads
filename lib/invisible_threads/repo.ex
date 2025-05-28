defmodule InvisibleThreads.Repo do
  use Ecto.Repo,
    otp_app: :invisible_threads,
    adapter: Ecto.Adapters.SQLite3
end
