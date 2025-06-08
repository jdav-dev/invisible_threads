defmodule InvisibleThreadsWeb.EmailThreadLive.Index do
  use InvisibleThreadsWeb, :live_view

  alias InvisibleThreads.Conversations

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Threads
        <:subtitle><span title="Postmark Server Name">{@current_scope.user.name}</span></:subtitle>
        <:actions>
          <div class="flex flex-col sm:flex-row gap-4 place-content-between">
            <div class="flex flex-col sm:flex-row gap-4">
              <.link
                href={~p"/users/delete-my-data"}
                class="btn btn-primary btn-soft"
                method="delete"
                title="Delete your data from Invisible Threads."
                data-confirm="This will delete all of your data from Invisible Threads and unset the inbound webhook on your Postmark server."
              >
                <.icon name="hero-trash" /> Delete my data
              </.link>
              <.link
                href={~p"/users/download-my-data"}
                class="btn btn-primary btn-soft"
                target="_blank"
                title="See everything Invisible Threads stores about you."
              >
                <.icon name="hero-arrow-top-right-on-square" /> Download my data
              </.link>
            </div>
            <div class="flex">
              <.link class="btn btn-primary w-full" navigate={~p"/threads/new"}>
                <.icon name="hero-plus" /> New Thread
              </.link>
            </div>
          </div>
        </:actions>
      </.header>

      <.table
        id="email_threads"
        rows={@streams.email_threads}
        row_click={fn {_id, email_thread} -> JS.navigate(~p"/threads/#{email_thread}") end}
      >
        <:col :let={{_id, email_thread}} label="Subject">
          <span class="line-clamp-1">{email_thread.subject}</span>
        </:col>
        <:col :let={{_id, email_thread}} label="Status">
          <.thread_status email_thread={email_thread} />
        </:col>
        <:action :let={{_id, email_thread}}>
          <div class="sr-only">
            <.link navigate={~p"/threads/#{email_thread}"}>Show</.link>
          </div>
        </:action>
        <:action :let={{_id, email_thread}}>
          <.link class="hidden sm:block" navigate={~p"/threads/#{email_thread}/duplicate"}>
            Duplicate
          </.link>
        </:action>
        <:action :let={{id, email_thread}}>
          <%= if email_thread.closed? do %>
            <.link
              class="hidden sm:block"
              phx-click={JS.push("delete", value: %{id: email_thread.id}) |> hide("##{id}")}
              data-confirm="Deleted threads cannot be restored."
            >
              Delete
            </.link>
          <% else %>
            <.link
              class="hidden sm:block"
              phx-click="close"
              phx-value-id={email_thread.id}
              data-confirm="This will message all participants.  Closed threads cannot be reopened."
            >
              Close
            </.link>
          <% end %>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Conversations.subscribe_email_threads(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Threads")
     |> stream(:email_threads, Conversations.list_email_threads(socket.assigns.current_scope))}
  end

  @impl Phoenix.LiveView
  def handle_event("close", %{"id" => email_thread_id}, socket) do
    case Conversations.close_email_thread(socket.assigns.current_scope, email_thread_id) do
      {:ok, updated_email_thread} ->
        {:noreply, stream_insert(socket, :email_threads, updated_email_thread)}

      {:error, :not_found} ->
        {:noreply, reset_stream(socket)}
    end
  end

  def handle_event("delete", %{"id" => email_thread_id}, socket) do
    case Conversations.delete_email_thread(socket.assigns.current_scope, email_thread_id) do
      :ok -> {:noreply, socket}
      {:error, :not_closed} -> {:noreply, reset_stream(socket)}
    end
  end

  defp reset_stream(socket) do
    stream(
      socket,
      :email_threads,
      Conversations.list_email_threads(socket.assigns.current_scope),
      reset: true
    )
  end

  @impl Phoenix.LiveView
  def handle_info({type, %InvisibleThreads.Conversations.EmailThread{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, reset_stream(socket)}
  end

  if Mix.env() == :test do
    # Ignore email messages during tests
    def handle_info({:emails, _emails}, socket) do
      {:noreply, socket}
    end
  end
end
