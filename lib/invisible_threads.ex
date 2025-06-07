defmodule InvisibleThreads do
  @moduledoc """
  InvisibleThreads keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Get the current release version.
  """
  def release do
    Application.get_env(:invisible_threads, :release)
  end
end
