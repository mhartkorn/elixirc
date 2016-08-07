defmodule ElixIRC do
  use Application

  def start(type, args) do
    Server.start(type, args)
  end
end
