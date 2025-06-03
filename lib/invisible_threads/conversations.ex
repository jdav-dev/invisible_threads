defmodule InvisibleThreads.Conversations do
  @moduledoc """
  The Conversations context.
  """

  import Ecto.Query, warn: false

  alias InvisibleThreads.Accounts.Scope
  alias InvisibleThreads.Conversations.EmailThread
  alias InvisibleThreads.Repo

  @doc """
  Subscribes to scoped notifications about any email_thread changes.

  The broadcasted messages match the pattern:

    * {:created, %EmailThread{}}
    * {:deleted, %EmailThread{}}

  """
  def subscribe_email_threads(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(InvisibleThreads.PubSub, "user:#{key}:email_threads")
  end

  defp broadcast(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(InvisibleThreads.PubSub, "user:#{key}:email_threads", message)
  end

  @doc """
  Returns the list of email_threads.

  ## Examples

      iex> list_email_threads(scope)
      [%EmailThread{}, ...]

  """
  def list_email_threads(%Scope{} = scope) do
    Repo.with_dynamic_repo(scope.user, fn ->
      Repo.all(from(email_thread in EmailThread))
    end)
  end

  @doc """
  Gets a single email_thread.

  Raises `Ecto.NoResultsError` if the Email thread does not exist.

  ## Examples

      iex> get_email_thread!(123)
      %EmailThread{}

      iex> get_email_thread!(456)
      ** (Ecto.NoResultsError)

  """
  def get_email_thread!(%Scope{} = scope, id) do
    Repo.with_dynamic_repo(scope.user, fn ->
      Repo.get!(EmailThread, id)
    end)
  end

  @doc """
  Creates a email_thread.

  ## Examples

      iex> create_email_thread(%{field: value})
      {:ok, %EmailThread{}}

      iex> create_email_thread(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_email_thread(%Scope{} = scope, attrs) do
    with {:ok, email_thread = %EmailThread{}} <-
           %EmailThread{}
           |> EmailThread.changeset(attrs, scope)
           |> then(&Repo.with_dynamic_repo(scope.user, fn -> Repo.insert(&1) end)) do
      broadcast(scope, {:created, email_thread})
      {:ok, email_thread}
    end
  end

  @doc """
  Deletes a email_thread.

  ## Examples

      iex> delete_email_thread(email_thread)
      {:ok, %EmailThread{}}

      iex> delete_email_thread(email_thread)
      {:error, %Ecto.Changeset{}}

  """
  def delete_email_thread(%Scope{} = scope, %EmailThread{} = email_thread) do
    with {:ok, email_thread = %EmailThread{}} <-
           Repo.with_dynamic_repo(scope.user, fn -> Repo.delete(email_thread) end) do
      broadcast(scope, {:deleted, email_thread})
      {:ok, email_thread}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking email_thread changes.

  ## Examples

      iex> change_email_thread(email_thread)
      %Ecto.Changeset{data: %EmailThread{}}

  """
  def change_email_thread(%Scope{} = scope, %EmailThread{} = email_thread, attrs \\ %{}) do
    EmailThread.changeset(email_thread, attrs, scope)
  end
end
