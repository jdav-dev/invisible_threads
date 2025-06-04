defmodule InvisibleThreadsWeb.EmailThreadLive.Show do
  use InvisibleThreadsWeb, :live_view

  alias InvisibleThreads.Conversations

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Email thread {@email_thread.id}
        <:subtitle>This is a email_thread record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/email_threads"}>
            <.icon name="hero-arrow-left" />
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Subject">{@email_thread.subject}</:item>
        <:item title="Recipients">
          <ul>
            <li :for={recipient <- @email_thread.recipients}>
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

    {:ok,
     socket
     |> assign(:page_title, "Show Email thread")
     |> assign(:email_thread, Conversations.get_email_thread!(socket.assigns.current_scope, id))}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:deleted, %InvisibleThreads.Conversations.EmailThread{id: id}},
        %{assigns: %{email_thread: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current email_thread was deleted.")
     |> push_navigate(to: ~p"/email_threads")}
  end

  def handle_info({type, %InvisibleThreads.Conversations.EmailThread{}}, socket)
      when type in [:created, :deleted] do
    {:noreply, socket}
  end
end
