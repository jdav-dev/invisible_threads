defmodule InvisibleThreadsWeb.EmailThreadLive.Form do
  use InvisibleThreadsWeb, :live_view

  alias InvisibleThreads.Conversations
  alias InvisibleThreads.Conversations.EmailRecipient
  alias InvisibleThreads.Conversations.EmailThread

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>
          Emails will be sent via the default broadcast stream with id "broadcast".
        </:subtitle>
      </.header>

      <.form for={@form} id="email_thread-form" phx-change="validate" phx-submit="save">
        <.input
          field={@form[:message_stream]}
          type="select"
          label="Message Stream"
          options={@message_stream_options}
        />
        <.input
          field={@form[:from]}
          type="email"
          label="Sender Email Address (must have a registered and confirmed Sender Signature in Postmark)"
          phx-debounce
          autocomplete="off"
        />
        <.input
          field={@form[:subject]}
          type="text"
          label="Email Thread Subject"
          phx-debounce
          autocomplete="off"
        />
        <.inputs_for :let={rf} field={@form[:recipients]}>
          <input type="hidden" name={"#{@form[:recipients_sort].name}[]"} value={rf.index} />
          <.input field={rf[:name]} type="text" label="Name" phx-debounce autocomplete="off" />
          <.input field={rf[:address]} type="email" label="Address" phx-debounce autocomplete="off" />
          <button
            type="button"
            class="btn"
            name={"#{@form[:recipients_drop].name}[]"}
            value={rf.index}
            phx-click={JS.dispatch("change")}
            disabled={@disable_remove_participant?}
          >
            <.icon name="hero-x-mark" class="w-6 h-6 relative top-2" />
          </button>
        </.inputs_for>
        <input type="hidden" name={"#{@form.name}[recipients_drop][]"} />
        <button
          type="button"
          class="btn"
          name={"#{@form.name}[recipients_sort][]"}
          value="new"
          phx-click={JS.dispatch("change")}
        >
          Add Thread Participant
        </button>
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Thread</.button>
          <.button navigate={return_path(@current_scope, @return_to, @email_thread)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    message_stream_options =
      case InvisibleThreads.Postmark.list_message_streams(
             socket.assigns.current_scope.user.server_token
           ) do
        {:ok, options} -> options
        _error -> ["broadcast"]
      end

    {:ok,
     socket
     |> assign(:message_stream_options, message_stream_options)
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :new, _params) do
    email_thread = %EmailThread{recipients: [%EmailRecipient{}, %EmailRecipient{}]}

    socket
    |> assign(:page_title, "New Thread")
    |> assign(:email_thread, email_thread)
    |> assign_form(Conversations.change_email_thread(socket.assigns.current_scope, email_thread))
  end

  defp apply_action(socket, :duplicate, %{"id" => email_thread_id}) do
    email_thread = Conversations.get_email_thread(socket.assigns.current_scope, email_thread_id)

    socket
    |> assign(:page_title, "Duplicate Thread")
    |> assign(:email_thread, email_thread)
    |> assign_form(Conversations.change_email_thread(socket.assigns.current_scope, email_thread))
  end

  defp assign_form(socket, changeset, opts \\ []) do
    form = to_form(changeset, opts)

    num_participants =
      Enum.count_until(
        form[:recipients].value,
        fn
          %EmailRecipient{} -> true
          %Ecto.Changeset{action: action} when action in [:insert, :update] -> true
          _other -> false
        end,
        3
      )

    socket
    |> assign(:form, form)
    |> assign(:disable_remove_participant?, num_participants <= 2)
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"email_thread" => email_thread_params}, socket) do
    changeset =
      Conversations.change_email_thread(
        socket.assigns.current_scope,
        socket.assigns.email_thread,
        email_thread_params
      )

    {:noreply, assign_form(socket, changeset, action: :validate)}
  end

  def handle_event("save", %{"email_thread" => email_thread_params}, socket) do
    save_email_thread(socket, socket.assigns.live_action, email_thread_params)
  end

  defp save_email_thread(socket, action, email_thread_params) when action in [:new, :duplicate] do
    case Conversations.create_email_thread(socket.assigns.current_scope, email_thread_params) do
      {:ok, email_thread} ->
        {:noreply,
         socket
         |> put_flash(:info, "Thread created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, email_thread)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp return_path(_scope, "index", _email_thread), do: ~p"/email_threads"
  defp return_path(_scope, "show", email_thread), do: ~p"/email_threads/#{email_thread}"
end
