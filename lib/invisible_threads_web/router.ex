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
      delete "/users/log-out", UserSessionController, :delete
    end
  end

  scope "/", InvisibleThreadsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{InvisibleThreadsWeb.UserAuth, :require_authenticated}] do
      live "/email_threads", EmailThreadLive.Index, :index
      live "/email_threads/new", EmailThreadLive.Form, :new
      live "/email_threads/:id", EmailThreadLive.Show, :show
      live "/email_threads/:id/duplicate", EmailThreadLive.Form, :duplicate
    end
  end

  scope "/api", InvisibleThreadsWeb do
    pipe_through :api

    post "/postmark/inbound_webhook/:user_id", PostmarkController, :inbound_webhook
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
          img: :img_csp_nonce,
          style: :style_csp_nonce,
          script: :script_csp_nonce
        },
        env_keys: [],
        home_app: {"Invisible Threads", :invisible_threads},
        metrics: InvisibleThreadsWeb.Telemetry

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  def put_csp(conn, _opts) do
    [img_nonce, style_nonce, script_nonce] =
      for _i <- 1..3 do
        16
        |> :crypto.strong_rand_bytes()
        |> Base.url_encode64(padding: false)
      end

    conn
    |> assign(:img_csp_nonce, img_nonce)
    |> assign(:style_csp_nonce, style_nonce)
    |> assign(:script_csp_nonce, script_nonce)
    |> put_secure_browser_headers(%{
      "content-security-policy" =>
        "default-src; " <>
          "script-src 'nonce-#{script_nonce}' 'self'; " <>
          "style-src-elem 'nonce-#{style_nonce}' 'self'; " <>
          "img-src 'nonce-#{img_nonce}' data: 'self'; " <>
          "font-src data: ; " <>
          "connect-src 'self'; " <>
          "frame-src 'self' ; " <>
          "base-uri 'self'; " <>
          "frame-ancestors 'self';"
    })
  end
end
