defmodule InvisibleThreads.ConversationsTest do
  use InvisibleThreads.DataCase, async: true

  alias InvisibleThreads.Conversations

  describe "email_threads" do
    import InvisibleThreads.AccountsFixtures, only: [user_scope_fixture: 0]
    import InvisibleThreads.ConversationsFixtures

    alias InvisibleThreads.Conversations.EmailRecipient
    alias InvisibleThreads.Conversations.EmailThread

    @invalid_attrs %{message_stream: nil, from: nil, subject: nil, recipients: nil}

    test "list_email_threads/1 returns all scoped email_threads" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      other_email_thread = email_thread_fixture(other_scope)
      assert Conversations.list_email_threads(scope) == [email_thread]
      assert Conversations.list_email_threads(other_scope) == [other_email_thread]
    end

    test "get_email_thread/2 returns the email_thread with given id" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      other_scope = user_scope_fixture()
      assert Conversations.get_email_thread(scope, email_thread.id) == email_thread
      refute Conversations.get_email_thread(other_scope, email_thread.id)
    end

    test "create_email_thread/2 with valid data creates a email_thread" do
      valid_attrs = %{
        message_stream: "broadcast",
        from: "from@example.com",
        subject: "some subject",
        recipients: [
          %{name: "Recipient 1", address: "one@example.com"},
          %{name: "Recipient 2", address: "two@example.com"}
        ]
      }

      scope = user_scope_fixture()

      assert {:ok, %EmailThread{} = email_thread} =
               Conversations.create_email_thread(scope, valid_attrs)

      assert email_thread.message_stream == "broadcast"
      assert email_thread.from == "from@example.com"
      assert email_thread.subject == "some subject"
      assert is_binary(email_thread.first_message_id)
      assert_email_sent(headers: %{"Message-ID" => email_thread.first_message_id})
      assert is_struct(email_thread.inserted_at, DateTime)

      assert email_thread.recipients == [
               %EmailRecipient{name: "Recipient 1", address: "one@example.com"},
               %EmailRecipient{name: "Recipient 2", address: "two@example.com"}
             ]
    end

    test "create_email_thread/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Conversations.create_email_thread(scope, @invalid_attrs)
    end

    test "delete_email_thread/2 deletes the email_thread" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      assert {:ok, %EmailThread{}} = Conversations.delete_email_thread(scope, email_thread)

      refute Conversations.get_email_thread(scope, email_thread.id)
    end

    test "delete_email_thread/2 with invalid scope is a no-op" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)

      assert {:ok, email_thread} == Conversations.delete_email_thread(other_scope, email_thread)
      refute Conversations.get_email_thread(other_scope, email_thread.id)
      assert email_thread == Conversations.get_email_thread(scope, email_thread.id)
    end

    test "change_email_thread/2 returns a email_thread changeset" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      assert %Ecto.Changeset{} = Conversations.change_email_thread(scope, email_thread)
    end
  end
end
