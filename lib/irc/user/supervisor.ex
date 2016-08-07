defmodule IRC.User.Supervisor do
  use Supervisor

  # A simple module attribute that stores the supervisor name
  @name IRC.User.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def start_send(socket) do
    Supervisor.start_child(@name, [[], [socket: socket]])
  end

  def init(:ok) do
    children = [
      worker(Server.UserSend, [], restart: :permanent)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
