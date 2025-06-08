defmodule InvisibleThreads.TestSwooshAdapter do
  @moduledoc """
  A test adapter for Swoosh that wraps `Swoosh.Adapters.Test`, but sets an ID like
  `Swoosh.Adapters.Local` and `Swoosh.Adapters.Postmark`.
  """

  use Swoosh.Adapter

  alias Swoosh.Adapters.Test

  @impl Swoosh.Adapter
  def deliver(email, config) do
    id = new_id()

    email =
      email
      |> Swoosh.Email.header("Message-ID", id)
      |> Swoosh.Email.put_private(:sent_at, DateTime.utc_now() |> DateTime.to_iso8601())

    with {:ok, metadata} <- Test.deliver(email, config) do
      {:ok, Map.put(metadata, :id, id)}
    end
  end

  defp new_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16() |> String.downcase()
  end

  @impl Swoosh.Adapter
  def deliver_many(emails, config) do
    sent_at = DateTime.utc_now() |> DateTime.to_iso8601()

    emails =
      for email <- emails do
        email
        |> Swoosh.Email.header("Message-ID", new_id())
        |> Swoosh.Email.put_private(:sent_at, sent_at)
      end

    {:ok, responses} = Test.deliver_many(emails, config)

    responses =
      for {email, response} <- Enum.zip(emails, responses) do
        Map.merge(response, %{
          id: email.headers["Message-ID"],
          error_code: 0,
          message: "OK",
          to: Enum.map_join(email.to, ", ", fn {name, address} -> ~s/"#{name}" <#{address}>/ end),
          submitted_at: sent_at
        })
      end

    {:ok, responses}
  end
end
