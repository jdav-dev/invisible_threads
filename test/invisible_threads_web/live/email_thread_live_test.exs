defmodule InvisibleThreadsWeb.EmailThreadLiveTest do
  use InvisibleThreadsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import InvisibleThreads.ConversationsFixtures

  @create_attrs %{
    message_stream: "broadcast",
    from: "from@example.com",
    subject: "some subject",
    recipients: %{
      "0" => %{name: "Recipient 1", address: "one@example.com"},
      "1" => %{name: "Recipient 2", address: "two@example.com"}
    }
  }
  @invalid_attrs %{subject: nil}

  setup :register_and_log_in_user

  describe "Index" do
    test "lists all email_threads", %{conn: conn, scope: scope} do
      email_thread = email_thread_fixture(scope)
      {:ok, _index_live, html} = live(conn, ~p"/threads")

      assert html =~ "Listing Threads"
      assert html =~ email_thread.subject
    end

    test "saves new email_thread", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/threads")

      assert {:ok, form_live, _html} =
               index_live
               |> element("a", "New Thread")
               |> render_click()
               |> follow_redirect(conn, ~p"/threads/new")

      assert render(form_live) =~ "New Thread"

      # Click the "add recipient" button twice
      render_change(form_live, :validate, email_thread: %{recipients_sort: ["new", "new"]})

      assert form_live
             |> form("#email_thread-form", email_thread: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#email_thread-form", email_thread: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/threads")

      html = render(index_live)
      assert html =~ "Thread created successfully"
      assert html =~ "some subject"
    end

    test "deletes email_thread in listing", %{conn: conn, scope: scope} do
      email_thread = email_thread_fixture(scope, closed?: true)
      {:ok, index_live, _html} = live(conn, ~p"/threads")

      assert index_live
             |> element("#email_threads-#{email_thread.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#email_threads-#{email_thread.id}")
    end
  end

  describe "Show" do
    test "displays email_thread", %{conn: conn, scope: scope} do
      email_thread = email_thread_fixture(scope)
      {:ok, _show_live, html} = live(conn, ~p"/threads/#{email_thread}")

      assert html =~ email_thread.subject
    end
  end
end
