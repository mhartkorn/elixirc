defmodule Server.ChannelRegistry do
  use GenServer
  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def stop(server) do
    GenServer.stop(server)
  end

  def new_channel(server, name, owner) do
    GenServer.call(server, {:new_channel, name, owner, %IRC.Channel{name: name}})
  end

  def find_channel(server, name) do
    GenServer.call(server, {:lookup, name})
  end

  ## Server Callbacks

  def init(:ok) do
    channels = %{}
    refs = %{}
    {:ok, {channels, refs}}
  end

  def handle_call({:new_channel, name, owner, channel}, _from, {channels, refs}) do
    if Map.has_key?(channels, name) do
      {:reply, {:already_exists, Map.get(channels, name)}, {channels, refs}}
    else
      Logger.debug "Creating channel '#{name}'"
      {:ok, pid} = IRC.Channel.Supervisor.start_channel(name, owner)
      ref = Process.monitor(pid)
      refs = Map.put(refs, ref, name)
      channels = Map.put(channels, name, {channel, pid})
      {:reply, {:ok, %{owner | channels: [name | owner.channels]}}, {channels, refs}}
    end
  end

  def handle_call({:lookup, name}, _from, {channels, refs}) do
    Logger.debug "Looking for channel '#{name}'"
    {:reply, Map.fetch(channels, name), {channels, refs}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, {channels, refs}) do
    {name, refs} = Map.pop(refs, ref)
    channels = Map.delete(channels, name)
    {:noreply, {channels, refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
