defmodule InvisibleThreadsWeb.PageController do
  use InvisibleThreadsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
