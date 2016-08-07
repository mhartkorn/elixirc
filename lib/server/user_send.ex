defmodule Server.UserSend do
  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:socket])
  end

  def stop(server) do
    GenServer.stop(server)
  end

  def send(server, message) do
    GenServer.call(server, {:send, message})
  end

  def init(socket) do
    socket = socket
    {:ok, socket}
  end

  def handle_call({:send, user, message}, _from, socket) do
    reply = :inet.send(socket, message)
    {:reply, reply, socket}
  end
end
