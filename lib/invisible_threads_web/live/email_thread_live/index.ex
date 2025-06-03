defmodule InvisibleThreadsWeb.EmailThreadLive.Index do
  use InvisibleThreadsWeb, :live_view

  alias InvisibleThreads.Conversations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Email threads
        <:actions>
          <.button variant="primary" navigate={~p"/email_threads/new"}>
            <.icon name="hero-plus" /> New Email thread
          </.button>
        </:actions>
      </.header>

      <.table
        id="email_threads"
        rows={@streams.email_threads}
        row_click={fn {_id, email_thread} -> JS.navigate(~p"/email_threads/#{email_thread}") end}
      >
        <:col :let={{_id, email_thread}} label="Name">{email_thread.name}</:col>
        <:col :let={{_id, email_thread}} label="Tag">{email_thread.tag}</:col>
        <:col :let={{_id, email_thread}} label="Recipients">{email_thread.recipients}</:col>
        <:action :let={{_id, email_thread}}>
          <div class="sr-only">
            <.link navigate={~p"/email_threads/#{email_thread}"}>Show</.link>
          </div>
          <.link navigate={~p"/email_threads/#{email_thread}/edit"}>Edit</.link>
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

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Conversations.subscribe_email_threads(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Email threads")
     |> stream(:email_threads, Conversations.list_email_threads(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    email_thread = Conversations.get_email_thread!(socket.assigns.current_scope, id)
    {:ok, _} = Conversations.delete_email_thread(socket.assigns.current_scope, email_thread)

    {:noreply, stream_delete(socket, :email_threads, email_thread)}
  end

  @impl true
  def handle_info({type, %InvisibleThreads.Conversations.EmailThread{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :email_threads, Conversations.list_email_threads(socket.assigns.current_scope), reset: true)}
  end
end
