defmodule InvisibleThreadsWeb.Router do
  use InvisibleThreadsWeb, :router

  import InvisibleThreadsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {InvisibleThreadsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => "default-src 'self'"}
    plug :fetch_current_scope_for_user
    plug :put_csp
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", InvisibleThreadsWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{InvisibleThreadsWeb.UserAuth, :mount_current_scope}] do
      get "/", PageController, :home

      live "/users/log-in", UserLive.Login, :new
      post "/users/log-in", UserSessionController, :create
      delete "/users/log-out", UserSessionController, :log_out
    end
  end

  scope "/", InvisibleThreadsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{InvisibleThreadsWeb.UserAuth, :require_authenticated}] do
      live "/threads", EmailThreadLive.Index, :index
      live "/threads/new", EmailThreadLive.Form, :new
      live "/threads/:id", EmailThreadLive.Show, :show
      live "/threads/:id/duplicate", EmailThreadLive.Form, :duplicate

      delete "/users/delete-my-data", UserSessionController, :delete_data
      get "/users/download-my-data", UserSessionController, :download_data
    end
  end

  scope "/api", InvisibleThreadsWeb do
    pipe_through :api

    post "/postmark/inbound_webhook/:user_id", PostmarkController, :inbound_webhook

    post "/postmark/unsubscribe/:user_id/:email_thread_id/:recipient_id",
         UnsubscribeController,
         :unsubscribe
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:invisible_threads, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
        allow_destructive_actions: true,
        csp_nonce_assign_key: %{
          style: :csp_nonce,
          script: :csp_nonce
        },
        env_keys: [],
        home_app: {"Invisible Threads", :invisible_threads},
        metrics: InvisibleThreadsWeb.Telemetry

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  def put_csp(conn, _opts) do
    csp_nonce = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    conn
    |> assign(:csp_nonce, csp_nonce)
    |> put_secure_browser_headers(%{
      "content-security-policy" =>
        "default-src; " <>
          "script-src 'nonce-#{csp_nonce}' 'self'; " <>
          "style-src-elem 'nonce-#{csp_nonce}' 'self'; " <>
          "style-src 'self'; " <>
          "img-src data: 'self'; " <>
          "font-src data: ; " <>
          "connect-src 'self'; " <>
          "frame-src 'self' ; " <>
          "base-uri 'self'; " <>
          "frame-ancestors 'self';"
    })
  end
end
