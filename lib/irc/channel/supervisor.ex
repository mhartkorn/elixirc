defmodule IRC.Channel.Supervisor do
  use Supervisor

  # A simple module attribute that stores the supervisor name
  @name IRC.Channel.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def start_channel(name, owner) do
    Supervisor.start_child(@name, [[], [name: name, owner: owner]])
  end

  def init(:ok) do
    children = [
      worker(IRC.Channel, [], restart: :permanent)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
