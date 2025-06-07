defmodule InvisibleThreads.Conversations do
  @moduledoc """
  The Conversations context.
  """

  import Ecto.Query, warn: false

  alias InvisibleThreads.Accounts
  alias InvisibleThreads.Accounts.Scope
  alias InvisibleThreads.Accounts.User
  alias InvisibleThreads.Conversations.EmailRecipient
  alias InvisibleThreads.Conversations.EmailThread
  alias InvisibleThreads.Conversations.ThreadNotifier

  @doc """
  Subscribes to scoped notifications about any email_thread changes.

  The broadcasted messages match the pattern:

    * {:created, %EmailThread{}}
    * {:updated, %EmailThread{}}
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
  Creates an email_thread.

  ## Examples

      iex> create_email_thread(%{field: value})
      %EmailThread{}

  """
  def create_email_thread(%Scope{} = scope, attrs) do
    with {:ok, email_thread} <- EmailThread.new(scope, attrs),
         {:ok, metadatas} <-
           ThreadNotifier.deliver_introduction(email_thread, scope.user) do
      ids_by_address = Map.new(metadatas, &{String.downcase(&1.to), &1.id})

      updated_email_thread =
        Map.update!(email_thread, :recipients, fn recipients ->
          Enum.map(recipients, fn recipient ->
            first_message_id = ids_by_address[String.downcase(recipient.address)]
            Map.replace!(recipient, :first_message_id, first_message_id)
          end)
        end)

      Accounts.update_user!(scope.user.id, fn user ->
        Map.update!(user, :email_threads, &[updated_email_thread | &1])
      end)

      broadcast(scope, {:created, updated_email_thread})

      {:ok, updated_email_thread}
    end
  end

  @doc """
  Closes an email_thread.

  ## Examples

      iex> close_email_thread(email_thread_id)
      {:ok, email_thread}

      iex> close_email_thread(invalid_id)
      {:error, :not_found}

  """
  def close_email_thread(%Scope{} = scope, email_thread_id) when is_binary(email_thread_id) do
    with %EmailThread{closed?: false} = email_thread <- get_email_thread(scope, email_thread_id),
         {:ok, _metadatas} <- ThreadNotifier.deliver_closing(email_thread, scope.user) do
      Accounts.update_user!(scope.user.id, &do_close_email_thread(&1, email_thread_id))
      updated_email_thread = struct!(email_thread, closed?: true)
      broadcast(scope, {:updated, updated_email_thread})
      {:ok, updated_email_thread}
    else
      %EmailThread{closed?: true} = email_thread -> {:ok, email_thread}
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_close_email_thread(user, email_thread_id) do
    Map.update!(user, :email_threads, fn email_threads ->
      Enum.map(email_threads, fn
        %EmailThread{id: ^email_thread_id} = email_thread ->
          struct!(email_thread, closed?: true)

        email_thread ->
          email_thread
      end)
    end)
  end

  @doc """
  Deletes a closed email_thread.

  Returns `{:error, :not_closed}` if the thread is not closed.

  ## Examples

      iex> delete_email_thread(scope, closed_email_thread_id)
      :ok

      iex> delete_email_thread(scope, open_email_thread_id)
      {:error, :not_closed}

  """
  def delete_email_thread(%Scope{} = scope, email_thread_id) when is_binary(email_thread_id) do
    case get_email_thread(scope, email_thread_id) do
      %EmailThread{closed?: true} = email_thread ->
        Accounts.update_user!(scope.user.id, &do_delete_email_thread(&1, email_thread_id))
        broadcast(scope, {:deleted, email_thread})
        :ok

      nil ->
        :ok

      %EmailThread{closed?: false} ->
        {:error, :not_closed}
    end
  end

  defp do_delete_email_thread(user, email_thread_id) do
    Map.update!(user, :email_threads, fn email_threads ->
      Enum.reject(email_threads, &(&1.id == email_thread_id and &1.closed?))
    end)
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

  @doc """
  Forward an inbound message to an email thread.
  """
  def forward_inbound_email(%Scope{} = scope, %{"MailboxHash" => mailbox_hash} = params) do
    with [email_thread_id, recipient_id] <- String.split(mailbox_hash, "_", parts: 2),
         %EmailThread{} = email_thread <- get_email_thread(scope, email_thread_id),
         %EmailRecipient{} = from_recipient <-
           Enum.find(email_thread.recipients, &(&1.id == recipient_id)) do
      ThreadNotifier.forward(email_thread, from_recipient, scope.user, params)
    else
      _other -> {:error, :unknown_thread}
    end
  end

  @doc """
  Remove a participant from an email thread.

  If less than two participants remain, the thread is deleted.
  """
  def unsubscribe!(user_id, email_thread_id, recipient_id) do
    if original_user = Accounts.get_user(user_id) do
      updated_user =
        Accounts.update_user!(user_id, &unsubscribe_recipient(&1, email_thread_id, recipient_id))

      scope = Scope.for_user(updated_user)
      updated_email_thread = Enum.find(updated_user.email_threads, &(&1.id == email_thread_id))

      if Enum.count_until(updated_email_thread.recipients, &(!&1.unsubscribed?), 2) < 2 do
        close_email_thread(scope, updated_email_thread.id)
      else
        original_email_thread =
          Enum.find(original_user.email_threads, &(&1.id == email_thread_id))

        unsubscribed_recipient =
          Enum.find(original_email_thread.recipients, &(&1.id == recipient_id))

        {:ok, _metadatas} =
          ThreadNotifier.deliver_unsubscribe(
            updated_email_thread,
            updated_user,
            unsubscribed_recipient
          )

        broadcast(scope, {:updated, updated_email_thread})
      end
    end

    :ok
  end

  defp unsubscribe_recipient(%User{} = user, email_thread_id, recipient_id) do
    Map.update!(user, :email_threads, &unsubscribe_recipient(&1, email_thread_id, recipient_id))
  end

  defp unsubscribe_recipient(email_threads, email_thread_id, recipient_id) do
    Enum.map(email_threads, fn
      %EmailThread{id: ^email_thread_id} = email_recipient ->
        unsubscribe_recipient(email_recipient, recipient_id)

      email_thread ->
        email_thread
    end)
  end

  defp unsubscribe_recipient(email_thread, recipient_id) do
    Map.update!(email_thread, :recipients, fn recipients ->
      Enum.map(recipients, fn
        %EmailRecipient{id: ^recipient_id} = email_recipient ->
          struct!(email_recipient, unsubscribed?: true)

        email_recipient ->
          email_recipient
      end)
    end)
  end

  @doc """
  Remove a participant from an email thread by recipient email address.

  If less than two participants remain, the thread is deleted.
  """
  def unsubscribe_by_address!(user_id, email_thread_id, recipient_address) do
    recipient_address = String.downcase(recipient_address)

    with %User{email_threads: email_threads} <- Accounts.get_user(user_id),
         %EmailThread{recipients: recipients} <-
           Enum.find(email_threads, &(&1.id == email_thread_id)),
         %EmailRecipient{id: recipient_id} <-
           Enum.find(recipients, &(String.downcase(&1.address) == recipient_address)) do
      unsubscribe!(user_id, email_thread_id, recipient_id)
    end

    :ok
  end
end
