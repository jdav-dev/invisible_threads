defmodule InvisibleThreads.Repo do
  use Ecto.Repo,
    otp_app: :invisible_threads,
    adapter: Ecto.Adapters.SQLite3

  @doc """
  Run migrations for a user's repo.
  """
  def migrate_repo(user) do
    with_dynamic_repo(user, fn ->
      Ecto.Migrator.run(__MODULE__, :up, all: true)
    end)
  end

  @doc """
  Run a function in the dynamic repo of an individual user.

  ## Examples

      iex> with_dynamic_repo(user, fn -> InvisibleThreads.Repo.query!("SELECT 1") end)
      %Exqlite.Result{command: :execute, columns: ["1"], rows: [[1]], num_rows: 1}

  """
  def with_dynamic_repo(user, callback) do
    default_dynamic_repo = get_dynamic_repo()

    {:ok, repo} =
      start_link(
        database: database(user),
        pool_size: 1,
        # FIXME: Remove the following options outside of dev
        stacktrace: true,
        show_sensitive_data_on_connection_error: true
      )

    try do
      put_dynamic_repo(repo)
      callback.()
    after
      put_dynamic_repo(default_dynamic_repo)
      Supervisor.stop(repo)
    end
  end

  def database(%InvisibleThreads.Accounts.User{id: user_id}) do
    Path.join(database_dir(), "user_#{user_id}.db")
  end

  @doc false
  def database_dir do
    :invisible_threads
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:database_dir, Path.expand("../../databases", __DIR__))
  end
end
