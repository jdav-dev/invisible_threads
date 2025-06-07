defmodule InvisibleThreadsWeb.EmailThreadLive.Show do
  use InvisibleThreadsWeb, :live_view

  alias InvisibleThreads.Conversations

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@email_thread.subject}
        <:actions>
          <div class="flex flex-col sm:flex-row gap-4 place-content-between">
            <.button navigate={~p"/threads"}>
              <.icon name="hero-arrow-left" /> All Threads
            </.button>
            <%= if @email_thread.closed? do %>
              <.button type="button" variant="primary" phx-click="delete">
                <.icon name="hero-trash" /> Delete thread
              </.button>
            <% else %>
              <.button type="button" variant="primary" phx-click="close">
                <.icon name="hero-x-circle" /> Close thread
              </.button>
            <% end %>
          </div>
        </:actions>
      </.header>

      <.list>
        <:item title="Message Stream">{@email_thread.message_stream}</:item>
        <:item title="Sender Email Address">{@email_thread.from}</:item>
        <:item title="Participants">
          <ul>
            <li
              :for={recipient <- @email_thread.recipients}
              class={if recipient.unsubscribed?, do: "line-through"}
            >
              {recipient.name} &lt;{recipient.address}&gt;
            </li>
          </ul>
        </:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Conversations.subscribe_email_threads(socket.assigns.current_scope)
    end

    email_thread = Conversations.get_email_thread(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, email_thread.subject)
     |> assign(:email_thread, email_thread)}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:updated, %InvisibleThreads.Conversations.EmailThread{id: id} = email_thread},
        %{assigns: %{email_thread: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :email_thread, email_thread)}
  end

  def handle_info(
        {:deleted, %InvisibleThreads.Conversations.EmailThread{id: id}},
        %{assigns: %{email_thread: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current email_thread was deleted.")
     |> push_navigate(to: ~p"/threads")}
  end

  def handle_info({type, %InvisibleThreads.Conversations.EmailThread{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
