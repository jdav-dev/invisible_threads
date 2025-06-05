defmodule InvisibleThreads.TestSwooshAdapter do
  @moduledoc """
  A test adapter for Swoosh that wraps `Swoosh.Adapters.Test`, but sets an ID like
  `Swoosh.Adapters.Local` and `Swoosh.Adapters.Sendgrid`.
  """

  use Swoosh.Adapter

  alias Swoosh.Adapters.Test

  @impl Swoosh.Adapter
  def deliver(email, config) do
    id = :crypto.strong_rand_bytes(16) |> Base.encode16() |> String.downcase()

    email =
      email
      |> Swoosh.Email.header("Message-ID", id)
      |> Swoosh.Email.put_private(:sent_at, DateTime.utc_now() |> DateTime.to_iso8601())

    with {:ok, metadata} <- Test.deliver(email, config) do
      {:ok, Map.put(metadata, :id, id)}
    end
  end

  @impl Swoosh.Adapter
  defdelegate deliver_many(emails, config), to: Test
end
