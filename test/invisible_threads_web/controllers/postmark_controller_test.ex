defmodule InvisibleThreadsWeb.PostmarkControllerTest do
  use InvisibleThreadsWeb.ConnCase, async: true

  import InvisibleThreads.AccountsFixtures
  import InvisibleThreads.ConversationsFixtures

  describe "POST /postmark/inbound_webhook/:user_id" do
    setup do
      {:ok, scope: user_scope_fixture()}
    end

    test "forwards an incoming email to a known thread", %{conn: conn, scope: scope} do
      email_thread = email_thread_fixture(scope)
      assert_email_sent()

      params = %{
        "MailboxHash" => email_thread.id,
        "FromName" => "some name",
        "TextBody" => "some text_body",
        "HtmlBody" => "some html_body",
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

      assert %{"id" => message_id} = json_response(conn, 200)

      assert_email_sent(fn email ->
        assert email.headers == %{
                 "Message-ID" => message_id,
                 "In-Reply-To" => email_thread.first_message_id,
                 "References" => email_thread.first_message_id
               }

        assert email.subject == email_thread.subject
        assert email.from == {"some name", "contact@example.com"}
        assert email.text_body == "some text_body"
        assert email.html_body == "some html_body"

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
      end)
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
  end
end
