defmodule IRC.Channel do
  defstruct name:  "",
            created: :os.system_time(:seconds),
            topic: "",
            flags: [], # List of channel flags
            users: [] # List of users

  require Logger

  def start_link(state, opts \\ []) do
    chan_owner = %IRC.ChannelUser{nick: opts[:owner].nick}
    GenServer.start_link(__MODULE__, %IRC.Channel{name: opts[:name], users: [chan_owner]})
  end

  def user_join(channel, user) do
    GenServer.call(channel, {:user_join, user})
  end

  def user_part(channel, user) do
    GenServer.call(channel, {:user_part, user})
  end

  def privmsg(channel, message) do
    GenServer.call(channel, {:privmsg, message})
  end

  def change_channel_flags(channel, flags) do
    GenServer.call(channel, {:set_flags, flags})
  end

  # Callbacks

  def init(channel) do
    {:ok, channel}
  end

  def handle_call({:user_join, user}, _from, channel) do
    chan_user = %IRC.ChannelUser{nick: user.nick}
    channel = %{channel | users: [chan_user | channel.users]}
    {:reply, %{user | channels: [channel.name | user.channels]}, channel}
  end

  def handle_call({:user_part, user}, _from, channel) do
    channel = %{channel | users: List.delete_at(channel.users, Enum.find_index(channel.users, fn e -> e.nick == user.nick end))}
    {:noreply, channel}
  end

  def handle_call({:privmsg, message}, _from, channel) do
    for u <- channel.users do
      case Server.UserRegistry.find_user_for_nick(UserRegistry, u.nick) do
        {:ok, user} -> Server.UserRegistry.send_message(UserRegistry, user, message)
        :error -> Logger.debug "User #{u.nick} not found despite being registered in channel #{channel.name}"
      end
     end
    {:noreply, channel}
  end

  def handle_call({:set_flags, flags}, _form, channel) do
    channel = %{channel | flags: [flags | channel.flags]}
    {:reply, channel.flags, channel}
  end

  # Internal

  defp find_user(channel, nick) do
    case Enum.find_index(channel.users, fn u -> u.nick == nick end) do
      index -> %{channel | users: List.delete_at(channel.users, index)}
      _ ->
        Logger.error "Unable to find parting user '#{nick}' in channel '#{channel.name}'"
        channel
    end
  end
end
