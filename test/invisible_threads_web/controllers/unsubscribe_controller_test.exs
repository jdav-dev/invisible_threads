defmodule InvisibleThreadsWeb.UnsubscribeControllerTest do
  use InvisibleThreadsWeb.ConnCase, async: true

  import InvisibleThreads.AccountsFixtures
  import InvisibleThreads.ConversationsFixtures

  alias InvisibleThreads.Conversations
  alias Swoosh.Email.Recipient

  describe "POST /api/postmark/unsubscribe/:user_id/:email_thread_id/:recipient_id" do
    setup do
      {:ok, scope: user_scope_fixture()}
    end

    test "removes a participant from an email thread", %{conn: conn, scope: scope} do
      email_thread =
        email_thread_fixture(scope,
          recipients: [
            %{name: "Recipient 1", address: "one@example.com"},
            %{name: "Recipient 2", address: "two@example.com"},
            %{name: "Recipient 3", address: "three@example.com"}
          ]
        )

      assert_emails_sent()

      [one, two, three] = email_thread.recipients

      conn = post(conn, ~p"/api/postmark/unsubscribe/#{scope.user}/#{email_thread}/#{one}")
      assert response(conn, 200) == ""

      updated_email_thread = Conversations.get_email_thread(scope, email_thread.id)
      refute one in updated_email_thread.recipients

      assert_emails_sent([
        %{
          to: [Recipient.format(two)],
          subject: email_thread.subject,
          text_body: "Recipient 1 has unsubscribed from this invisible thread.\n"
        },
        %{
          to: [Recipient.format(three)],
          subject: email_thread.subject,
          text_body: "Recipient 1 has unsubscribed from this invisible thread.\n"
        }
      ])
    end

    test "closes an email thread if less than two participants remain", %{
      conn: conn,
      scope: scope
    } do
      email_thread =
        email_thread_fixture(scope,
          recipients: [
            %{name: "Recipient 1", address: "one@example.com"},
            %{name: "Recipient 2", address: "two@example.com"}
          ]
        )

      assert_emails_sent()

      [one, two] = email_thread.recipients

      conn = post(conn, ~p"/api/postmark/unsubscribe/#{scope.user}/#{email_thread}/#{one}")
      assert response(conn, 200) == ""

      assert email_thread = Conversations.get_email_thread(scope, email_thread.id)
      assert email_thread.closed?

      assert_emails_sent([
        %{
          to: [Recipient.format(two)],
          subject: email_thread.subject,
          text_body:
            "This invisible thread has been closed.  No further messages will be delivered or shared.\n"
        }
      ])
    end
  end
end
