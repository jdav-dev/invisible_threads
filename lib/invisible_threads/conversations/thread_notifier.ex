defmodule InvisibleThreads.Conversations.ThreadNotifier do
  import Swoosh.Email

  alias InvisibleThreads.Mailer

  defp deliver(email_thread, inbound_address, body) do
    email =
      new()
      # TODO: Send from Postmark sender signature
      |> from({"Invisible Threads", "contact@example.com"})
      |> put_reply_to(email_thread, inbound_address)
      |> bcc(email_thread.recipients)
      |> subject(email_thread.subject)
      |> text_body(body)
      |> put_headers(email_thread.first_message_id)
      |> put_provider_option(:tag, email_thread.subject)

    with {:ok, %{id: message_id}} <- Mailer.deliver(email) do
      {:ok, message_id}
    end
  end

  defp put_reply_to(email, email_thread, inbound_address) do
    [mailbox_name, domain] = String.split(inbound_address, "@", parts: 2)
    reply_to(email, "#{mailbox_name}+#{email_thread.id}@#{domain}")
  end

  defp put_headers(email, in_reply_to) when is_binary(in_reply_to) do
    email
    |> header("In-Reply-To", in_reply_to)
    |> header("References", in_reply_to)
  end

  defp put_headers(email, nil), do: email

  def deliver_introduction(email_thread, inbound_address) do
    participants = email_thread.recipients |> Enum.map(& &1.name) |> Enum.join("\n- ")

    deliver(email_thread, inbound_address, """
    Hello,

    You've been added to an invisible thread — a shared conversation where all replies will be echoed to the group, but individual email addresses remain private.

    Participants in this thread:

    - #{participants}

    Feel free to reply to this message to start the conversation.  All responses will be visible to everyone on the thread.
    """)
  end

  def deliver_closing(email_thread, inbound_address) do
    deliver(email_thread, inbound_address, """
    This invisible thread has been closed.  No further messages will be delivered or shared.
    """)
  end
end
