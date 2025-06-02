defmodule InvisibleThreads.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias InvisibleThreads.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import InvisibleThreads.DataCase
    end
  end

  setup tags do
    InvisibleThreads.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    database_dir = InvisibleThreads.Repo.database_dir()

    on_exit(fn ->
      if !tags[:async] do
        database_dir
        |> Path.join("user_*.db")
        |> Path.wildcard()
        |> Enum.each(&File.rm!/1)
      end
    end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
