defmodule InvisibleThreads.Conversations.ThreadNotifier do
  @moduledoc """
  Deliver messages to email threads.
  """

  use InvisibleThreadsWeb, :verified_routes

  import Swoosh.Email

  alias InvisibleThreads.Mailer

  @doc """
  Deliver the initial introduction message to thread participants.

  """
  def deliver_introduction(email_thread, user) do
    email = new_email(email_thread)

    for recipient <- email_thread.recipients, !recipient.unsubscribed? do
      participants =
        Enum.map_join(email_thread.recipients, "\n- ", fn participant ->
          [participant.name, if(participant == recipient, do: " (you)", else: "")]
        end)

      email
      |> put_message_id(recipient)
      |> put_recipient(email_thread, recipient, user)
      |> text_body("""
      Hello #{recipient.name},

      You've been added to an invisible thread - a group email conversation where replies are shared with all participants, but email addresses stay hidden.

      Participants:

      - #{participants}

      Simply reply to this email as you normally would.  Addresses stay private, but anything you include in your message (like a signature) will be visible to others.

      For best results, reply from the same address that received this email.  Reply STOP to unsubscribe.
      """)
    end
    |> Mailer.deliver_many(api_key: user.server_token)
  end

  defp new_email(email_thread, from_name \\ "Invisible Threads") do
    new()
    |> from({from_name, email_thread.from})
    |> subject(email_thread.subject)
    |> put_provider_option(:message_stream, email_thread.message_stream)
    |> put_provider_option(:tag, email_thread.subject)
  end

  defp put_recipient(email, email_thread, recipient, user) do
    [mailbox_name, domain] = String.split(user.inbound_address, "@", parts: 2)
    recipient_reply_to = "#{mailbox_name}+#{email_thread.id}_#{recipient.id}@#{domain}"

    email
    |> to(recipient)
    |> reply_to(recipient_reply_to)
    |> put_unsubscribe_headers(user, email_thread, recipient, recipient_reply_to)
  end

  defp put_message_id(email, recipient) do
    message_id = first_message_id(recipient)
    header(email, "Message-ID", message_id)
  end

  defp first_message_id(recipient) do
    host = InvisibleThreadsWeb.Endpoint.host()
    "<#{recipient.id}@#{host}>"
  end

  defp put_unsubscribe_headers(email, user, email_thread, recipient, recipient_reply_to) do
    unsubscribe_url = url(~p"/api/postmark/unsubscribe/#{user}/#{email_thread}/#{recipient}")

    email
    |> header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
    |> header(
      "List-Unsubscribe",
      "<#{unsubscribe_url}>, <mailto:#{recipient_reply_to}?subject=unsubscribe>"
    )
  end

  @doc """
  Deliver a message notifying participants when someone has unsubscribed.

  """
  def deliver_unsubscribe(email_thread, user, unsubscribed_recipient) do
    email = new_email(email_thread, unsubscribed_recipient.name)

    for recipient <- email_thread.recipients, !recipient.unsubscribed? do
      email
      |> put_in_reply_headers(recipient)
      |> put_recipient(email_thread, recipient, user)
      |> text_body("""
      #{unsubscribed_recipient.name} has unsubscribed from this invisible thread.
      """)
    end
    |> Mailer.deliver_many(api_key: user.server_token)
  end

  defp put_in_reply_headers(email, recipient) do
    first_message_id = first_message_id(recipient)

    email
    |> header("In-Reply-To", first_message_id)
    |> header("References", first_message_id)
  end

  @doc """
  Deliver a message notifying participants when the thread is closed.

  """
  def deliver_closing(email_thread, user) do
    email = new_email(email_thread)

    for recipient <- email_thread.recipients, !recipient.unsubscribed? do
      email
      |> put_in_reply_headers(recipient)
      |> put_recipient(email_thread, recipient, user)
      |> text_body("""
      This invisible thread has been closed.  No further messages will be delivered or shared.
      """)
    end
    |> Mailer.deliver_many(api_key: user.server_token)
  end

  @doc """
  Forward a message from one participant to the rest.

  """
  def forward(email_thread, from_recipient, user, params) do
    params = redact(params, email_thread)

    email =
      email_thread
      |> new_email(from_recipient.name)
      |> text_body(params["TextBody"])
      |> html_body(params["HtmlBody"])
      |> put_attachments(params["Attachments"])

    for recipient <- email_thread.recipients,
        !recipient.unsubscribed?,
        recipient.id != from_recipient.id do
      email
      |> put_in_reply_headers(recipient)
      |> put_recipient(email_thread, recipient, user)
    end
    |> Mailer.deliver_many(api_key: user.server_token)
  end

  defp redact(params, email_thread) do
    regex =
      email_thread.recipients
      |> Enum.map_join("|", &Regex.escape(&1.address))
      |> Regex.compile!([:caseless])

    for key <- ["TextBody", "HtmlBody"], reduce: params do
      acc -> Map.replace_lazy(acc, key, &Regex.replace(regex, &1, "████████"))
    end
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
