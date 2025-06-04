defmodule InvisibleThreads.Conversations do
  @moduledoc """
  The Conversations context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias InvisibleThreads.Accounts.Scope
  alias InvisibleThreads.Conversations.EmailThread
  alias InvisibleThreads.Conversations.ThreadNotifier
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
    email_thread_changeset = EmailThread.changeset(%EmailThread{}, attrs, scope)

    Multi.new()
    |> Multi.insert(:email_thread, email_thread_changeset)
    |> Multi.run(:deliver_introduction, fn _repo, %{email_thread: email_thread} ->
      ThreadNotifier.deliver_introduction(email_thread, scope.user.inbound_address)
    end)
    |> Multi.update(:set_message_id, fn %{
                                          email_thread: email_thread,
                                          deliver_introduction: message_id
                                        } ->
      EmailThread.first_message_id_changeset(email_thread, message_id)
    end)
    |> then(&Repo.with_dynamic_repo(scope.user, fn -> Repo.transaction(&1) end))
    |> case do
      {:ok, %{set_message_id: email_thread}} ->
        broadcast(scope, {:created, email_thread})
        {:ok, email_thread}

      {:error, _name, reason, _changes_so_far} ->
        {:error, reason}
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
    Multi.new()
    |> Multi.delete(:email_thread, email_thread)
    |> Multi.run(:deliver_closing, fn _repo, %{email_thread: email_thread} ->
      ThreadNotifier.deliver_closing(email_thread, scope.user.inbound_address)
    end)
    |> then(&Repo.with_dynamic_repo(scope.user, fn -> Repo.transaction(&1) end))
    |> case do
      {:ok, %{email_thread: email_thread}} ->
        broadcast(scope, {:deleted, email_thread})
        {:ok, email_thread}

      {:error, _name, reason, _changes_so_far} ->
        {:error, reason}
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
