defmodule InvisibleThreads.ConversationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `InvisibleThreads.Conversations` context.
  """

  @doc """
  Generate a email_thread.
  """
  def email_thread_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        subject: "some subject",
        recipients: [
          %{name: "Recipient 1", address: "one@example.com"},
          %{name: "Recipient 2", address: "two@example.com"}
        ]
      })

    {:ok, email_thread} = InvisibleThreads.Conversations.create_email_thread(scope, attrs)
    email_thread
  end
end
