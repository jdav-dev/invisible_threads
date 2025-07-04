defmodule InvisibleThreads.ConversationsTest do
  use InvisibleThreads.DataCase, async: true

  alias InvisibleThreads.Conversations
  alias Swoosh.Email.Recipient

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

      [one, two] = email_thread.recipients

      assert_emails_sent([
        %{subject: email_thread.subject, to: Recipient.format(one)},
        %{subject: email_thread.subject, to: Recipient.format(two)}
      ])

      assert is_struct(email_thread.inserted_at, DateTime)

      assert [
               %EmailRecipient{name: "Recipient 1", address: "one@example.com"},
               %EmailRecipient{name: "Recipient 2", address: "two@example.com"}
             ] = email_thread.recipients
    end

    test "create_email_thread/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Conversations.create_email_thread(scope, @invalid_attrs)
    end

    test "close_email_thread/2 closes the email_thread" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)
      assert {:ok, email_thread} = Conversations.close_email_thread(scope, email_thread.id)
      assert email_thread.closed?
    end

    test "close_email_thread/2 is a no-op for already closed threads" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope, closed?: true)
      assert {:ok, _email_thread} = Conversations.close_email_thread(scope, email_thread.id)
      assert email_thread == Conversations.get_email_thread(scope, email_thread.id)
    end

    test "close_email_thread/2 returns {:error, :not_found} for unknown threads" do
      scope = user_scope_fixture()
      assert {:error, :not_found} = Conversations.close_email_thread(scope, "unknown")
    end

    test "close_email_thread/2 with invalid scope returns {:error, :not_found}" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope)

      assert {:error, :not_found} = Conversations.close_email_thread(other_scope, email_thread.id)
      assert email_thread == Conversations.get_email_thread(scope, email_thread.id)
    end

    test "delete_email_thread/2 deletes the email_thread" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope, closed?: true)
      assert :ok = Conversations.delete_email_thread(scope, email_thread.id)

      refute Conversations.get_email_thread(scope, email_thread.id)
    end

    test "delete_email_thread/2 returns error for open threads" do
      scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope, closed?: false)
      assert {:error, :not_closed} = Conversations.delete_email_thread(scope, email_thread.id)

      assert Conversations.get_email_thread(scope, email_thread.id)
    end

    test "delete_email_thread/2 with invalid scope is a no-op" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      email_thread = email_thread_fixture(scope, closed?: true)

      assert :ok == Conversations.delete_email_thread(other_scope, email_thread.id)
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
