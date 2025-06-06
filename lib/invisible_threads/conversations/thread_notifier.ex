defmodule InvisibleThreads.Conversations.ThreadNotifier do
  import Swoosh.Email

  alias InvisibleThreads.Mailer

  defp deliver(email, email_thread, inbound_address) do
    email =
      email
      |> put_reply_to(email_thread, inbound_address)
      |> bcc(email_thread.recipients)
      |> subject(email_thread.subject)
      |> put_headers(email_thread.first_message_id)
      |> put_provider_option(:message_stream, email_thread.message_stream)
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

    new()
    |> from({"Invisible Threads", email_thread.from})
    |> text_body("""
    Hello,

    You've been added to an invisible thread — a shared conversation where all replies will be echoed to the group, but individual email addresses remain private.

    Participants in this thread:

    - #{participants}

    Feel free to reply to this message to start the conversation.  All responses will be visible to everyone on the thread.
    """)
    |> deliver(email_thread, inbound_address)
  end

  def deliver_closing(email_thread, inbound_address) do
    new()
    |> from({"Invisible Threads", email_thread.from})
    |> text_body("""
    This invisible thread has been closed.  No further messages will be delivered or shared.
    """)
    |> deliver(email_thread, inbound_address)
  end

  def forward(email_thread, inbound_address, params) do
    from_email = String.downcase(params["FromFull"]["Email"])

    email_thread =
      Map.update!(email_thread, :recipients, fn recipients ->
        Enum.reject(recipients, fn email_recipient ->
          String.downcase(email_recipient.address) == from_email
        end)
      end)

    new()
    |> from({params["FromFull"]["Name"], email_thread.from})
    |> text_body(params["TextBody"])
    |> html_body(params["HtmlBody"])
    |> put_attachments(params["Attachments"])
    |> deliver(email_thread, inbound_address)
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
