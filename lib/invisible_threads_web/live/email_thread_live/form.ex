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
          Threads cannot be changed once created.  The sender email address must have a registered
          and confirmed
          <.link class="link" href="https://account.postmarkapp.com/signature_domains">
            Sender Signature
          </.link>
          in Postmark.  When a thread is created, an introduction email will immediately go out to
          all participants.
        </:subtitle>
        <:actions>
          <div class="flex flex-col sm:flex-row gap-4 place-content-between">
            <.button navigate={~p"/threads"}>
              <.icon name="hero-arrow-left" /> All Threads
            </.button>
          </div>
        </:actions>
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
          label="Sender Email Address"
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
          <span>Participant</span>
          <input type="hidden" name={"#{@form[:recipients_sort].name}[]"} value={rf.index} />
          <div class="w-full flex flex-col sm:flex-row gap-x-4 items-center">
            <div class="w-full">
              <.input field={rf[:name]} type="text" label="Name" phx-debounce autocomplete="off" />
            </div>
            <div class="w-full flex gap-x-4 items-center">
              <div class="w-full flex-grow">
                <.input
                  field={rf[:address]}
                  type="email"
                  label="Address"
                  phx-debounce
                  autocomplete="off"
                />
              </div>
              <button
                type="button"
                class="btn btn-primary btn-soft flex-none mt-3.5"
                name={"#{@form[:recipients_drop].name}[]"}
                value={rf.index}
                phx-click={JS.dispatch("change")}
                disabled={@num_participants <= 2}
              >
                <.icon name="hero-trash" class="w-6 h-6" />
              </button>
            </div>
          </div>
        </.inputs_for>
        <input type="hidden" name={"#{@form.name}[recipients_drop][]"} />
        <footer class="mt-3 flex flex-col sm:flex-row gap-4 place-content-between">
          <button
            type="button"
            class="btn btn-primary btn-soft"
            name={"#{@form.name}[recipients_sort][]"}
            value="new"
            phx-click={JS.dispatch("change")}
            phx-disable-with="Adding..."
            disabled={@num_participants >= 50}
          >
            <.icon name="hero-user-plus" /> Add Participant
          </button>
          <.button phx-disable-with="Saving..." variant="primary">
            Create Thread
          </.button>
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

    changeset =
      socket.assigns.current_scope
      |> Conversations.change_email_thread(email_thread)
      |> Ecto.Changeset.put_change(:subject, "#{email_thread.subject} (copy)")

    socket
    |> assign(:page_title, "Duplicate Thread")
    |> assign(:email_thread, email_thread)
    |> assign_form(changeset)
  end

  defp assign_form(socket, changeset, opts \\ []) do
    form = to_form(changeset, opts)

    num_participants =
      Enum.count(
        form[:recipients].value,
        fn
          %EmailRecipient{} -> true
          %Ecto.Changeset{action: action} when action in [:insert, :update] -> true
          _other -> false
        end
      )

    socket
    |> assign(:form, form)
    |> assign(:num_participants, num_participants)
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

  defp return_path(_scope, "index", _email_thread), do: ~p"/threads"
  defp return_path(_scope, "show", email_thread), do: ~p"/threads/#{email_thread}"
end
