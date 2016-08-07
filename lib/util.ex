defmodule Util do
  @doc """
  Converts a tuple provided by `:inet.peername/1` to a string
  """
  def convertIpPortToString(ip_port) do
    {ip, port} = ip_port
    ip_string = if tuple_size(ip) == 4 do
        Enum.join(Tuple.to_list(ip), ".")
      else
        "[" <> Enum.join(Enum.map(
          Tuple.to_list(ip), fn(e) -> Integer.to_string(e, 16) end),
          ":") <> "]"
      end

    ip_string <> ":" <> Integer.to_string(port)
  end
end
