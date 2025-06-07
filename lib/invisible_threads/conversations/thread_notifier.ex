defmodule InvisibleThreads.Conversations.ThreadNotifier do
  @moduledoc """
  Deliver messages to email threads.
  """

  use InvisibleThreadsWeb, :verified_routes

  import Swoosh.Email

  alias InvisibleThreads.Mailer

  defp deliver(email, email_thread, user) do
    [mailbox_name, domain] = String.split(user.inbound_address, "@", parts: 2)

    email =
      email
      |> subject(email_thread.subject)
      |> put_provider_option(:message_stream, email_thread.message_stream)
      |> put_provider_option(:tag, email_thread.subject)

    emails =
      for recipient <- email_thread.recipients do
        recipient_reply_to = "#{mailbox_name}+#{email_thread.id}_#{recipient.id}@#{domain}"

        email
        |> to(recipient)
        |> reply_to(recipient_reply_to)
        |> put_in_reply_headers(recipient.first_message_id)
        |> put_unsubscribe_headers(user, email_thread, recipient, recipient_reply_to)
      end

    with {:ok, metadatas} <- Mailer.deliver_many(emails, api_key: user.server_token) do
      {:ok, metadatas}
    end
  end

  defp put_in_reply_headers(email, in_reply_to) when is_binary(in_reply_to) do
    email
    |> header("In-Reply-To", in_reply_to)
    |> header("References", in_reply_to)
  end

  defp put_in_reply_headers(email, nil), do: email

  defp put_unsubscribe_headers(email, user, email_thread, recipient, recipient_reply_to) do
    unsubscribe_url = url(~p"/api/postmark/unsubscribe/#{user}/#{email_thread}/#{recipient}")

    email
    |> header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
    |> header(
      "List-Unsubscribe",
      "<#{unsubscribe_url}>, <mailto:#{recipient_reply_to}?subject=unsubscribe>"
    )
  end

  def deliver_introduction(email_thread, user) do
    participants = Enum.map_join(email_thread.recipients, "\n- ", & &1.name)

    new()
    |> from({"Invisible Threads", email_thread.from})
    |> text_body("""
    Hello,

    You've been added to an invisible thread — a shared conversation where all replies will be echoed to the group, but individual email addresses remain private.

    Participants in this thread:

    - #{participants}

    Feel free to reply to this message to start the conversation.  All responses will be visible to everyone on the thread.
    """)
    |> deliver(email_thread, user)
  end

  def deliver_unsubscribe(email_thread, user, unsubscribed_recipient) do
    new()
    |> from({unsubscribed_recipient.name, email_thread.from})
    |> text_body("""
    #{unsubscribed_recipient.name} has unsubscribed from this thread.
    """)
    |> deliver(email_thread, user)
  end

  def deliver_closing(email_thread, user) do
    new()
    |> from({"Invisible Threads", email_thread.from})
    |> text_body("""
    This invisible thread has been closed.  No further messages will be delivered or shared.
    """)
    |> deliver(email_thread, user)
  end

  def forward(email_thread, from_recipient, user, params) do
    email_thread =
      Map.update!(email_thread, :recipients, fn recipients ->
        Enum.reject(recipients, &(&1.id == from_recipient.id))
      end)

    new()
    |> from({from_recipient.name, email_thread.from})
    |> text_body(params["TextBody"])
    |> html_body(params["HtmlBody"])
    |> put_attachments(params["Attachments"])
    |> deliver(email_thread, user)
  end

  defp put_attachments(email, attachments) do
    for %{
          "Name" => file_name,
          "Content" => content,
          "ContentType" => content_type,
          "ContentID" => content_id
        } <- Enum.reverse(attachments),
        reduce: email do
      acc ->
        data = Base.decode64!(content)

        inline_params =
          case content_id do
            cid when is_binary(cid) and cid != "" -> [type: :inline, cid: cid]
            _cid -> []
          end

        attachment(
          acc,
          Swoosh.Attachment.new({:data, data}, [
            {:filename, file_name},
            {:content_type, content_type} | inline_params
          ])
        )
    end
  end
end
