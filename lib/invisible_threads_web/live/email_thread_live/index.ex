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
              <.button type="button">
                <.icon name="hero-trash" /> Delete my data
              </.button>
              <.button type="button">
                <.icon name="hero-arrow-down-tray" /> Download my data
              </.button>
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
        <:col :let={{_id, email_thread}} label="Subject">{email_thread.subject}</:col>
        <:col :let={{_id, email_thread}} label="Participants">
          {format_participants(email_thread)}
        </:col>
        <:action :let={{_id, email_thread}}>
          <div class="sr-only">
            <.link navigate={~p"/threads/#{email_thread}"}>Show</.link>
          </div>
        </:action>
        <:action :let={{_id, email_thread}}>
          <.link navigate={~p"/threads/#{email_thread}/duplicate"}>Duplicate</.link>
        </:action>
        <:action :let={{id, email_thread}}>
          <.link
            phx-click={JS.push("delete", value: %{id: email_thread.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  defp format_participants(email_thread) do
    email_thread.recipients
    |> Enum.reject(& &1.unsubscribed?)
    |> Enum.map_join(", ", & &1.name)
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
  def handle_event("delete", %{"id" => id}, socket) do
    :ok = Conversations.delete_email_thread(socket.assigns.current_scope, id)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({type, %InvisibleThreads.Conversations.EmailThread{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(
       socket,
       :email_threads,
       Conversations.list_email_threads(socket.assigns.current_scope),
       reset: true
     )}
  end

  if Mix.env() == :test do
    # Ignore email messages during tests
    def handle_info({:emails, _emails}, socket) do
      {:noreply, socket}
    end
  end
end
