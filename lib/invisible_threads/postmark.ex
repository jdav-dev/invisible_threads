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
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :invalid_token}

      error ->
        Logger.error(["Error calling Postmark:\n\tError: ", inspect(error)])
        :error
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
end
