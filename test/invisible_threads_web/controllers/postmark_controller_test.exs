defmodule InvisibleThreadsWeb.PostmarkControllerTest do
  use InvisibleThreadsWeb.ConnCase, async: true

  import InvisibleThreads.AccountsFixtures
  import InvisibleThreads.ConversationsFixtures

  alias InvisibleThreads.Conversations
  alias Swoosh.Email.Recipient

  describe "POST /api/postmark/inbound_webhook/:user_id" do
    setup do
      {:ok, scope: user_scope_fixture()}
    end

    test "forwards an incoming email to a known thread", %{conn: conn, scope: scope} do
      email_thread = email_thread_fixture(scope)
      assert_emails_sent()

      [from_recipient, to_recipient] = email_thread.recipients

      params = %{
        "MailboxHash" => "#{email_thread.id}_#{from_recipient.id}",
        "TextBody" =>
          "some text_body <#{String.upcase(from_recipient.address)}> <#{to_recipient.address}>",
        "HtmlBody" =>
          "some html_body <#{from_recipient.address}> <#{String.downcase(to_recipient.address)}>",
        "Attachments" => [
          %{
            "Name" => "one.txt",
            "Content" => "Zmlyc3QgY29udGVudA==",
            "ContentType" => "text/plain",
            "ContentID" => ""
          },
          %{
            "Name" => "two.txt",
            "Content" => "c2Vjb25kIGNvbnRlbnQ=",
            "ContentType" => "text/plain",
            "ContentID" => "some_cid"
          }
        ]
      }

      conn =
        conn
        |> put_req_header(
          "authorization",
          Plug.BasicAuth.encode_basic_auth("postmark", scope.user.inbound_webhook_password)
        )
        |> post(~p"/api/postmark/inbound_webhook/#{scope.user}", params)

      assert response(conn, 200)

      email =
        receive do
          {:emails, [email]} ->
            email

          {:emails, emails} ->
            flunk("Expected 1 bulk email, received: #{inspect(emails, pretty: true)}")
        after
          100 -> flunk("No bulk emails were sent")
        end

      assert email.headers["In-Reply-To"] =~ to_recipient.id
      assert email.headers["References"] =~ to_recipient.id

      assert email.from == {from_recipient.name, email_thread.from}
      assert email.to == [Recipient.format(to_recipient)]
      assert email.subject == email_thread.subject

      assert email.text_body == "some text_body <████████> <████████>"
      assert email.html_body == "some html_body <████████> <████████>"

      assert email.attachments == [
               %Swoosh.Attachment{
                 filename: "one.txt",
                 data: "first content",
                 content_type: "text/plain",
                 type: :attachment
               },
               %Swoosh.Attachment{
                 filename: "two.txt",
                 data: "second content",
                 content_type: "text/plain",
                 type: :inline,
                 cid: "some_cid"
               }
             ]
    end

    test "returns 401 for unknown users", %{conn: conn} do
      conn = post(conn, ~p"/api/postmark/inbound_webhook/unknown_user", %{})
      assert response(conn, 401) == "Unauthorized"
    end

    test "returns 401 for incorrect passwords", %{conn: conn, scope: scope} do
      conn =
        conn
        |> put_req_header(
          "authorization",
          Plug.BasicAuth.encode_basic_auth("postmark", "incorrect password")
        )
        |> post(~p"/api/postmark/inbound_webhook/#{scope.user}", %{})

      assert response(conn, 401) == "Unauthorized"
    end

    test "returns 403 for unknown threads", %{conn: conn, scope: scope} do
      params = %{"MailboxHash" => "unknown_thread"}

      conn =
        conn
        |> put_req_header(
          "authorization",
          Plug.BasicAuth.encode_basic_auth("postmark", scope.user.inbound_webhook_password)
        )
        |> post(~p"/api/postmark/inbound_webhook/#{scope.user}", params)

      assert response(conn, 403) == "Forbidden"
    end

    test "unsubscribes recipients when the subject is unsubscribe", %{conn: conn, scope: scope} do
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

      params = %{
        "Subject" => "unsubscribe",
        "MailboxHash" => email_thread.id,
        "FromFull" => %{
          "Email" => one.address
        }
      }

      conn =
        conn
        |> put_req_header(
          "authorization",
          Plug.BasicAuth.encode_basic_auth("postmark", scope.user.inbound_webhook_password)
        )
        |> post(~p"/api/postmark/inbound_webhook/#{scope.user}", params)

      assert response(conn, 200)

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

      params = %{
        "Subject" => "unsubscribe",
        "MailboxHash" => email_thread.id,
        "FromFull" => %{
          "Email" => one.address
        }
      }

      conn =
        conn
        |> put_req_header(
          "authorization",
          Plug.BasicAuth.encode_basic_auth("postmark", scope.user.inbound_webhook_password)
        )
        |> post(~p"/api/postmark/inbound_webhook/#{scope.user}", params)

      assert response(conn, 200)

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
