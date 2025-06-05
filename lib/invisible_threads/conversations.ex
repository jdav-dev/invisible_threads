defmodule InvisibleThreads.Conversations do
  @moduledoc """
  The Conversations context.
  """

  import Ecto.Query, warn: false

  alias InvisibleThreads.Accounts
  alias InvisibleThreads.Accounts.Scope
  alias InvisibleThreads.Conversations.EmailThread
  alias InvisibleThreads.Conversations.ThreadNotifier

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
    user = Accounts.get_user(scope.user.id)
    user.email_threads
  end

  @doc """
  Gets a single email_thread.

  Raises `nil` if the Email thread does not exist.

  ## Examples

      iex> get_email_thread(123)
      %EmailThread{}

      iex> get_email_thread(456)
      nil

  """
  def get_email_thread(%Scope{} = scope, id) do
    user = Accounts.get_user(scope.user.id)
    Enum.find(user.email_threads, &(&1.id == id))
  end

  @doc """
  Creates a email_thread.

  ## Examples

      iex> create_email_thread(%{field: value})
      %EmailThread{}

  """
  def create_email_thread(%Scope{} = scope, attrs) do
    with {:ok, email_thread} <- EmailThread.new(scope, attrs),
         {:ok, message_id} <-
           ThreadNotifier.deliver_introduction(email_thread, scope.user.inbound_address) do
      updated_email_thread = struct!(email_thread, first_message_id: message_id)

      Accounts.update_user!(scope.user.id, fn user ->
        struct!(user, email_threads: [updated_email_thread | user.email_threads])
      end)

      broadcast(scope, {:created, updated_email_thread})

      {:ok, updated_email_thread}
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
    with {:ok, _message_id} <-
           ThreadNotifier.deliver_closing(email_thread, scope.user.inbound_address) do
      Accounts.update_user!(scope.user.id, fn user ->
        struct!(user, email_threads: Enum.reject(user.email_threads, &(&1.id == email_thread.id)))
      end)

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

  def forward_inbound_email(%Scope{} = scope, %{"MailboxHash" => email_thread_id} = params) do
    case get_email_thread(scope, email_thread_id) do
      %EmailThread{} = email_thread ->
        ThreadNotifier.forward(email_thread, scope.user.inbound_address, params)

      nil ->
        {:error, :unknown_thread}
    end
  end
end
