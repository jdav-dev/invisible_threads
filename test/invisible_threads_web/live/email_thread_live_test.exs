defmodule InvisibleThreadsWeb.EmailThreadLiveTest do
  use InvisibleThreadsWeb.ConnCase

  import Phoenix.LiveViewTest
  import InvisibleThreads.ConversationsFixtures

  @create_attrs %{name: "some name", tag: "some tag", recipients: ["option1", "option2"]}
  @update_attrs %{name: "some updated name", tag: "some updated tag", recipients: ["option1"]}
  @invalid_attrs %{name: nil, tag: nil, recipients: []}

  setup :register_and_log_in_user

  defp create_email_thread(%{scope: scope}) do
    email_thread = email_thread_fixture(scope)

    %{email_thread: email_thread}
  end

  describe "Index" do
    setup [:create_email_thread]

    test "lists all email_threads", %{conn: conn, email_thread: email_thread} do
      {:ok, _index_live, html} = live(conn, ~p"/email_threads")

      assert html =~ "Listing Email threads"
      assert html =~ email_thread.name
    end

    test "saves new email_thread", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/email_threads")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Email thread")
               |> render_click()
               |> follow_redirect(conn, ~p"/email_threads/new")

      assert render(form_live) =~ "New Email thread"

      assert form_live
             |> form("#email_thread-form", email_thread: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#email_thread-form", email_thread: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/email_threads")

      html = render(index_live)
      assert html =~ "Email thread created successfully"
      assert html =~ "some name"
    end

    test "updates email_thread in listing", %{conn: conn, email_thread: email_thread} do
      {:ok, index_live, _html} = live(conn, ~p"/email_threads")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#email_threads-#{email_thread.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/email_threads/#{email_thread}/edit")

      assert render(form_live) =~ "Edit Email thread"

      assert form_live
             |> form("#email_thread-form", email_thread: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#email_thread-form", email_thread: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/email_threads")

      html = render(index_live)
      assert html =~ "Email thread updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes email_thread in listing", %{conn: conn, email_thread: email_thread} do
      {:ok, index_live, _html} = live(conn, ~p"/email_threads")

      assert index_live
             |> element("#email_threads-#{email_thread.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#email_threads-#{email_thread.id}")
    end
  end

  describe "Show" do
    setup [:create_email_thread]

    test "displays email_thread", %{conn: conn, email_thread: email_thread} do
      {:ok, _show_live, html} = live(conn, ~p"/email_threads/#{email_thread}")

      assert html =~ "Show Email thread"
      assert html =~ email_thread.name
    end

    test "updates email_thread and returns to show", %{conn: conn, email_thread: email_thread} do
      {:ok, show_live, _html} = live(conn, ~p"/email_threads/#{email_thread}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/email_threads/#{email_thread}/edit?return_to=show")

      assert render(form_live) =~ "Edit Email thread"

      assert form_live
             |> form("#email_thread-form", email_thread: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#email_thread-form", email_thread: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/email_threads/#{email_thread}")

      html = render(show_live)
      assert html =~ "Email thread updated successfully"
      assert html =~ "some updated name"
    end
  end
end
