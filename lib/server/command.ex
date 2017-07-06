defmodule Server.Command do
  require Logger

  def parse(socket, user, line) do
    # Split the line at all spaces
    lineSplits = String.split(String.trim(line), " ")

    beginning = if Enum.at(lineSplits, 0, "") |> String.length > 0 && String.at(Enum.at(lineSplits, 0), 0) == ":" do
        Logger.debug "Encountered extended format"
        1
      else
        0
      end

    command = String.downcase(Enum.at(lineSplits, beginning))
    {_, rest} = Enum.split(lineSplits, beginning + 1)

    if IRC.User.has_full_cmd_access?(user) do
      case command do
        "pong" -> cmd_pong(socket, user, rest)
        "privmsg" -> cmd_privmsg(socket, user, rest)
        "join" -> cmd_join(socket, user, rest)
        "part" -> cmd_part(socket, user, rest)
        "quit" -> cmd_quit(socket, user, rest)
        "nick" -> cmd_quit(socket, user, rest)
        _ -> {:error, :unknown_command, String.upcase(command)}
      end
    else
      case command do
        "pong" -> cmd_pong(socket, user, rest)
        "user" -> cmd_user(socket, user, rest)
        "nick" -> cmd_nick(socket, user, rest)
        "quit" -> cmd_quit(socket, user, rest)
        _ -> {:error, :unknown_command, String.upcase(command)}
      end
    end
  end

  def get_source(socket) do
    case :inet.peername(socket) do
      {:ok, ip_port} -> ip_port
      {:error, _} -> Process.exit(self, :kill)
    end
  end

  defp cmd_privmsg(_socket, user, linesplits) do
    # Missing validity checks
    Logger.debug "Got 'PRIVMSG #{Enum.join(linesplits, " ")}' from '#{user.nick}'"

    if length(linesplits) < 1 do
      {:error, "PRIVMSG", user}
    else
      case Server.ChannelRegistry.find_channel(ChannelRegistry, Enum.at(linesplits, 0)) do
        {:ok, channel} ->
          message = Enum.chunk(linesplits, 1, length(linesplits)) |> Enum.join(" ")
          IRC.Channel.privmsg(elem(channel, 1), message)
          {:ok, "PRIVMSG", user}
        _ ->
          Logger.error "No such channel..."
          {:error, "PRIVMSG", user}
      end
    end
  end

  defp cmd_join(_socket, user, linesplits) do
    Logger.debug "Got JOIN '#{Enum.join(linesplits, " ")}' from '#{user.nick}'"

    linesplitLength = length(linesplits)
    user = if linesplitLength > 0 do
      name = Enum.at(linesplits, 0)

      if String.at(name, 0) == "#" do
        case Server.ChannelRegistry.find_channel(ChannelRegistry, name) do
          {:ok, {_, pid}} ->
            Logger.debug "Channel already exists '#{name}', joining..."
            IRC.Channel.user_join(pid, user)
          :error ->
            Logger.info "Channel '#{name}' does not exist, creating new one"
            case Server.ChannelRegistry.new_channel(ChannelRegistry, name, user) do
              {:ok, new_user} ->
                Logger.debug "'#{new_user.nick}' joined channel #{name}"
                new_user
              {:already_exists, {channel, pid}} ->
                Logger.debug "Channel '#{channel.name}' exists, '#{user.nick}' joining..."
                IRC.Channel.user_join(pid, user)
            end
        end
      end
    end

    {:ok, "JOIN", user}
  end

  def cmd_part(_socket, user, linesplits) do
    Logger.debug "Got PART '#{Enum.join(linesplits, " ")}' from '#{user.nick}'"


  end

  def nick_valid?(nick) do
    true # TODO implement
  end

  defp cmd_nick(_socket, user, linesplits) do
    linesplitLength = length(linesplits)

    user = if linesplitLength > 0 do
      nick = Enum.at(linesplits, 0)
      Logger.debug "Set nick from '#{user.nick}' to '#{nick}'"
      %{user | nick: nick}
    else
      user
    end

    {:ok, "NICK", user}
  end

  defp cmd_user(_socket, user, linesplits) do
    # TODO implement correctly
    linesplitLength = length(linesplits)

    user = if linesplitLength > 0 do
      name = Enum.at(linesplits, 0)
      Logger.debug "Set user command to '#{name}'"
      %{user | name: name}
    else
      user
    end

    {:ok, "USER", user}
  end

  defp cmd_pong(_socket, user, _linesplits) do
    {:ok, "PONG", user}
  end

  defp cmd_quit(socket, user, _linesplits) do
    :gen_tcp.close(socket)
    for chan <- user.channels do
      {:ok, {_, pid}} = Server.ChannelRegistry.find_channel(ChannelRegistry, chan.name)
      IRC.Channel.user_part(pid, user)
    end

    {:quit, %{user | channels: []}}
  end
end
