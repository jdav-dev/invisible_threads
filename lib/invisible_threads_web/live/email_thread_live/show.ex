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
            <div class="flex flex-col sm:flex-row gap-4">
              <.button navigate={~p"/threads/#{@email_thread}/duplicate"}>
                Duplicate
              </.button>
              <%= if @email_thread.closed? do %>
                <.button
                  type="button"
                  variant="primary"
                  phx-click="delete"
                  data-confirm="Deleted threads cannot be restored."
                >
                  <.icon name="hero-trash" /> Delete thread
                </.button>
              <% else %>
                <.button
                  type="button"
                  variant="primary"
                  phx-click="close"
                  data-confirm="This will message all participants.  Closed threads cannot be reopened."
                >
                  <.icon name="hero-x-circle" /> Close thread
                </.button>
              <% end %>
            </div>
          </div>
        </:actions>
      </.header>

      <.list>
        <:item title="Status"><.thread_status email_thread={@email_thread} /></:item>
        <:item title="Message Stream">{@email_thread.message_stream}</:item>
        <:item title="Sender Email Address">{@email_thread.from}</:item>
        <:item title={"Participants (#{count_active_participants(@email_thread)})"}>
          <ul>
            <li :for={recipient <- @email_thread.recipients}>
              <span class={if recipient.unsubscribed?, do: "line-through"}>
                {recipient.name} &lt;{recipient.address}&gt;
              </span>
              <%= if recipient.unsubscribed? do %>
                <small class="badge badge-error badge-sm">Unsubscribed</small>
              <% end %>
            </li>
          </ul>
        </:item>
      </.list>
    </Layouts.app>
    """
  end

  defp count_active_participants(email_thread) do
    Enum.count(email_thread.recipients, &(!&1.unsubscribed?))
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
  def handle_event("close", _params, socket) do
    %{current_scope: current_scope, email_thread: %{id: email_thread_id}} = socket.assigns

    case Conversations.close_email_thread(current_scope, email_thread_id) do
      {:ok, email_thread} ->
        {:noreply, assign(socket, :email_thread, email_thread)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "The current thread was not found.")
         |> push_navigate(to: ~p"/threads")}
    end
  end

  def handle_event("delete", _params, socket) do
    %{current_scope: current_scope, email_thread: %{id: email_thread_id}} = socket.assigns

    case Conversations.delete_email_thread(current_scope, email_thread_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:error, "Thread deleted successfully.")
         |> push_navigate(to: ~p"/threads")}

      {:error, :not_closed} ->
        {:noreply,
         socket
         |> put_flash(:error, "The current thread was not closed.")
         |> push_navigate(to: ~p"/threads/#{email_thread_id}")}
    end
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
     |> put_flash(:error, "The current thread was deleted.")
     |> push_navigate(to: ~p"/threads")}
  end

  def handle_info({type, %InvisibleThreads.Conversations.EmailThread{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
