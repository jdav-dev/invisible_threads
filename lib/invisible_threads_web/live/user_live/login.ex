defmodule InvisibleThreadsWeb.UserLive.Login do
  use InvisibleThreadsWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <.header class="text-center">
          <p>Log in with Postmark Server API token</p>
        </.header>

        <div class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>It is recommended to create a dedicated Postmark server for Invisible Threads.</p>
            <p>The inbound webhook of the provided server will be updated during login.</p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form"
          action={~p"/users/log-in"}
          phx-submit="submit"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            field={@form[:password]}
            type="password"
            label="Server API token"
            autocomplete="off"
          />
          <.input
            :if={!@current_scope}
            field={f[:remember_me]}
            type="checkbox"
            label="Keep me logged in"
          />
          <.button class="w-full" variant="primary">
            Log in <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
