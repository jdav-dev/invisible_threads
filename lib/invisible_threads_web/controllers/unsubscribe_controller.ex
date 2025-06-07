defmodule InvisibleThreadsWeb.UnsubscribeController do
  use InvisibleThreadsWeb, :controller

  alias InvisibleThreads.Conversations

  def unsubscribe(conn, %{
        "user_id" => user_id,
        "email_thread_id" => email_thread_id,
        "recipient_id" => recipient_id
      }) do
    Conversations.unsubscribe!(user_id, email_thread_id, recipient_id)
    send_resp(conn, 200, "")
  end
end
