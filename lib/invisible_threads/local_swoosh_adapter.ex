defmodule InvisibleThreads.LocalSwooshAdapter do
  @moduledoc ~S"""
  An adapter that stores the email locally, using the specified storage driver.

  This is a wrapper of `Swoosh.Adapters.Local` that includes `to` in the metadata returned by
  `deliver_many/2`.  This is consistent with `Swoosh.Adapters.Postmark`.
  """

  use Swoosh.Adapter

  defdelegate deliver(email, config), to: Swoosh.Adapters.Local

  def deliver_many(emails, config) when is_list(emails) do
    driver = storage_driver(config)

    sent_email_metadatas =
      Enum.map(emails, fn email ->
        %Swoosh.Email{to: to, headers: %{"Message-ID" => id}} = driver.push(email)
        %{id: id, to: to |> List.first() |> elem(1)}
      end)

    {:ok, sent_email_metadatas}
  end

  defp storage_driver(config) do
    config[:storage_driver] || Swoosh.Adapters.Local.Storage.Memory
  end
end
