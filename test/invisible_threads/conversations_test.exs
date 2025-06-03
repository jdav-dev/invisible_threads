defmodule InvisibleThreads.ConversationsTest do
  use InvisibleThreads.DataCase

  alias InvisibleThreads.Conversations

  describe "email_threads" do
    alias InvisibleThreads.Conversations.EmailThread

    import InvisibleThreads.AccountsFixtures, only: [user_scope_fixture: 0]
    import InvisibleThreads.ConversationsFixtures

    @invalid_attrs %{name: nil, tag: nil, recipients: nil}

    test "list_email_threads/1 returns all scoped email_threads" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      other_email_thread = email_thread_fixture(other_scope)
      assert Conversations.list_email_threads(scope) == [email_thread]
      assert Conversations.list_email_threads(other_scope) == [other_email_thread]
    end

    test "get_email_thread!/2 returns the email_thread with given id" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      other_scope = user_scope_fixture()
      assert Conversations.get_email_thread!(scope, email_thread.id) == email_thread
      assert_raise Ecto.NoResultsError, fn -> Conversations.get_email_thread!(other_scope, email_thread.id) end
    end

    test "create_email_thread/2 with valid data creates a email_thread" do
      valid_attrs = %{name: "some name", tag: "some tag", recipients: ["option1", "option2"]}
      scope = user_scope_fixture()

      assert {:ok, %EmailThread{} = email_thread} = Conversations.create_email_thread(scope, valid_attrs)
      assert email_thread.name == "some name"
      assert email_thread.tag == "some tag"
      assert email_thread.recipients == ["option1", "option2"]
      assert email_thread.user_id == scope.user.id
    end

    test "create_email_thread/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Conversations.create_email_thread(scope, @invalid_attrs)
    end

    test "update_email_thread/3 with valid data updates the email_thread" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      update_attrs = %{name: "some updated name", tag: "some updated tag", recipients: ["option1"]}

      assert {:ok, %EmailThread{} = email_thread} = Conversations.update_email_thread(scope, email_thread, update_attrs)
      assert email_thread.name == "some updated name"
      assert email_thread.tag == "some updated tag"
      assert email_thread.recipients == ["option1"]
    end

    test "update_email_thread/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)

      assert_raise MatchError, fn ->
        Conversations.update_email_thread(other_scope, email_thread, %{})
      end
    end

    test "update_email_thread/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Conversations.update_email_thread(scope, email_thread, @invalid_attrs)
      assert email_thread == Conversations.get_email_thread!(scope, email_thread.id)
    end

    test "delete_email_thread/2 deletes the email_thread" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      assert {:ok, %EmailThread{}} = Conversations.delete_email_thread(scope, email_thread)
      assert_raise Ecto.NoResultsError, fn -> Conversations.get_email_thread!(scope, email_thread.id) end
    end

    test "delete_email_thread/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      assert_raise MatchError, fn -> Conversations.delete_email_thread(other_scope, email_thread) end
    end

    test "change_email_thread/2 returns a email_thread changeset" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      assert %Ecto.Changeset{} = Conversations.change_email_thread(scope, email_thread)
    end
  end
end
