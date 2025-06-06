defmodule InvisibleThreads.Postmark do
  @moduledoc """
  The Postmark context.
  """

  require Logger

  @doc """
  [Get the server](https://postmarkapp.com/developer/api/server-api#get-server).
  """
  def get_server(server_token) do
    server_token
    |> new_req()
    |> Req.get(url: "/server")
    |> case do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      error -> handle_error(error)
    end
  end

  defp new_req(server_token) do
    [
      base_url: "https://api.postmarkapp.com",
      headers: [x_postmark_server_token: server_token]
    ]
    |> Keyword.merge(Application.get_env(:invisible_threads, :postmark_req_options, []))
    |> Req.new()
  end

  defp handle_error(error) do
    case error do
      {:ok, %Req.Response{status: 401}} ->
        {:error, :invalid_token}

      error ->
        Logger.error(["Error calling Postmark:\n\tError: ", inspect(error)])
        :error
    end
  end

  @doc """
  [List message streams](https://postmarkapp.com/developer/api/message-streams-api#list-message-streams).
  """
  def list_broadcast_streams(server_token) do
    server_token
    |> new_req()
    |> Req.get(url: "/message-streams", params: %{"MessageStreamType" => "Broadcasts"})
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"MessageStreams" => message_streams}}} ->
        options = for %{"Name" => name, "ID" => id} <- message_streams, do: {name, id}
        {:ok, options}

      error ->
        handle_error(error)
    end
  end

  @doc """
  [Edit the server](https://postmarkapp.com/developer/api/server-api#get-server) to point its
  incoming email towards this app.
  """
  def set_inbound_hook_url(server_token, inbound_hook_url) do
    params = %{"InboundHookUrl" => inbound_hook_url}

    server_token
    |> new_req()
    |> Req.put(url: "/server", json: params)
    |> case do
      {:ok, %Req.Response{status: 200}} -> :ok
      error -> handle_error(error)
    end
  end
end
