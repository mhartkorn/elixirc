defmodule Server.UserRegistry do
  use GenServer
  require Logger

  ## Client API

  @doc """
  Starts the registry with the given `name`.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  @doc """
  Stops the registry.
  """
  def stop(server) do
    GenServer.stop(server)
  end

  def new_user(server, socket) do
    GenServer.call(server, {:new_user, socket})
  end

  def find_user_for_socket(server, ip_port) do
    GenServer.call(server, {:lookup, ip_port})
  end

  def delete_user(server, user) do
    GenServer.call(server, {:delete_user, user})
  end

  def send_message(server, user, message) do
    GenServer.call(server, {:send_message, user, message})
  end

  @doc """
  Ensures there is a bucket associated to the given `name` in `server`.
  """
  def create(server, name) do
    GenServer.cast(server, {:create, name})
  end

  ## Server Callbacks

  def init(:ok) do
    users = %{}
    {:ok, users}
  end

  def handle_call({:new_user, socket}, _from, state) do
    {:ok, ip_port} = :inet.peername(socket)

    ip_port_str = Util.convertIpPortToString(ip_port)
    if Map.has_key?(state, ip_port_str) do
      {:reply, :already_connected, state}
    else
      Logger.debug "Adding user '#{ip_port_str}'"

      {:ok, pid} = IRC.User.Supervisor.start_send(socket)

      user = %IRC.User{send_pid: pid}

      state = Map.put(state, ip_port_str, user)
      {:reply, {:ok, user}, state}
    end
  end

  def handle_call({:delete_user, nick}, _from, state) do
    Map.delete(state, nick)
    {:noreply, state}
  end

  def handle_call({:lookup, ip_port}, _from, state) do
    ip_port_str = Util.convertIpPortToString(ip_port)
    Logger.debug "Looking for user '#{ip_port_str}'"
    {:reply, Map.fetch(state, ip_port_str), state}
  end

  def handle_call({:send_message, user, message}, _from, state) do
    if IRC.User.has_nick?(user) do
      Map.get(state, user.nick)
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    {name, refs} = Map.pop(refs, ref)
    names = Map.delete(names, name)
    {:noreply, {names, refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
