defmodule InvisibleThreadsWeb.EmailThreadLive.Show do
  use InvisibleThreadsWeb, :live_view

  alias InvisibleThreads.Conversations

  @impl true
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
          <.button variant="primary" navigate={~p"/email_threads/#{@email_thread}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit email_thread
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@email_thread.name}</:item>
        <:item title="Tag">{@email_thread.tag}</:item>
        <:item title="Recipients">{@email_thread.recipients}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Conversations.subscribe_email_threads(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Email thread")
     |> assign(:email_thread, Conversations.get_email_thread!(socket.assigns.current_scope, id))}
  end

  @impl true
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
     |> push_navigate(to: ~p"/email_threads")}
  end

  def handle_info({type, %InvisibleThreads.Conversations.EmailThread{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
