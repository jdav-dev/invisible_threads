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

  def forward_inbound_email(params) do
    dbg(params)

    # {
    #   "From": "myUser@theirDomain.com",
    #   "MessageStream": "inbound",
    #   "FromName": "My User",
    #   "FromFull": {
    #     "Email": "myUser@theirDomain.com",
    #     "Name": "John Doe",
    #     "MailboxHash": ""
    #   },
    #   "To": "451d9b70cf9364d23ff6f9d51d870251569e+ahoy@inbound.postmarkapp.com",
    #   "ToFull": [
    #     {
    #       "Email": "451d9b70cf9364d23ff6f9d51d870251569e+ahoy@inbound.postmarkapp.com",
    #       "Name": "",
    #       "MailboxHash": "ahoy"
    #     }
    #   ],
    #   "Cc": "\"Full name\" <sample.cc@emailDomain.com>, \"Another Cc\" <another.cc@emailDomain.com>",
    #   "CcFull": [
    #     {
    #       "Email": "sample.cc@emailDomain.com",
    #       "Name": "Full name",
    #       "MailboxHash": ""
    #     },
    #     {
    #       "Email": "another.cc@emailDomain.com",
    #       "Name": "Another Cc",
    #       "MailboxHash": ""
    #     }
    #   ],
    #   "Bcc": "\"Full name\" <451d9b70cf9364d23ff6f9d51d870251569e@inbound.postmarkapp.com>",
    #   "BccFull": [
    #     {
    #       "Email": "451d9b70cf9364d23ff6f9d51d870251569e@inbound.postmarkapp.com",
    #       "Name": "Full name",
    #       "MailboxHash": ""
    #     }
    #   ],
    #   "OriginalRecipient": "451d9b70cf9364d23ff6f9d51d870251569e+ahoy@inbound.postmarkapp.com",
    #   "ReplyTo": "myUsersReplyAddress@theirDomain.com",
    #   "Subject": "This is an inbound message",
    #   "MessageID": "22c74902-a0c1-4511-804f-341342852c90",
    #   "Date": "Thu, 5 Apr 2012 16:59:01 +0200",
    #   "MailboxHash": "ahoy",
    #   "TextBody": "[ASCII]",
    #   "HtmlBody": "[HTML]",
    #   "StrippedTextReply": "Ok, thanks for letting me know!",
    #   "Tag": "",
    #   "Headers": [
    #     {
    #       "Name": "X-Spam-Checker-Version",
    #       "Value": "SpamAssassin 3.3.1 (2010-03-16) onrs-ord-pm-inbound1.wildbit.com"
    #     },
    #     {
    #       "Name": "X-Spam-Status",
    #       "Value": "No"
    #     },
    #     {
    #       "Name": "X-Spam-Score",
    #       "Value": "-0.1"
    #     },
    #     {
    #       "Name": "X-Spam-Tests",
    #       "Value": "DKIM_SIGNED,DKIM_VALID,DKIM_VALID_AU,SPF_PASS"
    #     },
    #     {
    #       "Name": "Received-SPF",
    #       "Value": "Pass (sender SPF authorized) identity=mailfrom; client-ip=209.85.160.180; helo=mail-gy0-f180.google.com; envelope-from=myUser@theirDomain.com; receiver=451d9b70cf9364d23ff6f9d51d870251569e+ahoy@inbound.postmarkapp.com"
    #     },
    #     {
    #       "Name": "DKIM-Signature",
    #       "Value": "v=1; a=rsa-sha256; c=relaxed/relaxed;        d=wildbit.com; s=google;        h=mime-version:reply-to:message-id:subject:from:to:cc         :content-type;        bh=cYr/+oQiklaYbBJOQU3CdAnyhCTuvemrU36WT7cPNt0=;        b=QsegXXbTbC4CMirl7A3VjDHyXbEsbCUTPL5vEHa7hNkkUTxXOK+dQA0JwgBHq5C+1u         iuAJMz+SNBoTqEDqte2ckDvG2SeFR+Edip10p80TFGLp5RucaYvkwJTyuwsA7xd78NKT         Q9ou6L1hgy/MbKChnp2kxHOtYNOrrszY3JfQM="
    #     },
    #     {
    #       "Name": "MIME-Version",
    #       "Value": "1.0"
    #     },
    #     {
    #       "Name": "Message-ID",
    #       "Value": "<CAGXpo2WKfxHWZ5UFYCR3H_J9SNMG+5AXUovfEFL6DjWBJSyZaA@mail.gmail.com>"
    #     }
    #   ],
    #   "Attachments": [
    #     {
    #       "Name": "myimage.png",
    #       "Content": "[BASE64-ENCODED CONTENT]",
    #       "ContentType": "image/png",
    #       "ContentLength": 4096,
    #       "ContentID": "myimage.png@01CE7342.75E71F80"
    #     },
    #     {
    #       "Name": "mypaper.doc",
    #       "Content": "[BASE64-ENCODED CONTENT]",
    #       "ContentType": "application/msword",
    #       "ContentLength": 16384,
    #       "ContentID": ""
    #     }
    #   ]
    # }

    :ok
  end
end
