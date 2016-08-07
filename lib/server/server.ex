defmodule Server do
  def start(_tags, _args) do
     import Supervisor.Spec

     children = [
       supervisor(Task.Supervisor, [[name: IRC.Server.ConnectionSupervisor]]),
       supervisor(IRC.Channel.Supervisor, []),
       supervisor(IRC.User.Supervisor, []),
       worker(Task, [Server, :accept, [4040]]),
       worker(Server.UserRegistry, [UserRegistry]),
       worker(Server.ChannelRegistry, [ChannelRegistry])
     ]

     opts = [strategy: :one_for_one, name: Server.Supervisor]
     Supervisor.start_link(children, opts)
   end

  require Logger

  def accept(port) do
    # The options below mean:
    #
    # 1. `:binary` - receives data as binaries (instead of lists)
    # 2. `packet: :line` - receives data line by line
    # 3. `active: false` - blocks on `:gen_tcp.recv/2` until data is available
    # 4. `reuseaddr: true` - allows us to reuse the address if the listener crashes
    #
    {:ok, socket} = :gen_tcp.listen(port,
                      [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(IRC.Server.ConnectionSupervisor, fn -> new_client(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp new_client(socket) do
    user = case Server.UserRegistry.new_user(UserRegistry, socket) do
      {:ok, u} ->
        Logger.info "New user connected"
        u
      :already_connected ->
        Logger.error "User already connected, something went wrong, aborting connection"
        :gen_tcp.close(socket)
        exit(:normal)
    end

    serve(socket, user)
  end

  defp serve(socket, user) do
    {state, user} =
      case read_line(socket) do
        {:ok, data} ->
          case Server.Command.parse(socket, user, data) do
            {:ok, command, new_user} ->
              Logger.info "Command parsed: #{command}"
              {:continue, new_user}
            {:quit, user} ->
              Logger.info "User '#{user.nick}' quit"
              {:quit, user}
            {:error, :unknown_command, command} ->
              Logger.error "Error while parsing command: Unknown command #{command}"
              {:continue, user}
            {:error, :cannot_find_source} ->
              Logger.error "Source user is not registered."
              {:continue, user}
            {:error, _} ->
              Logger.error "Error while parsing command."
              {:continue, user}
            _ ->
              Logger.error "Heavy error!"
              {:quit, user}
          end
        {:error, err} ->
          Logger.error "Error while reading data from socket: #{err}"
          user
      end

    case state do
      :continue -> serve(socket, user)
      :quit ->
        Server.UserRegistry.delete_user(UserRegistry, user.name)
        exit(:normal)
    end
  end

  defp read_line(socket) do
    {:ok, _data} = :gen_tcp.recv(socket, 0)
  end
end
