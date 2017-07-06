defmodule IRC.User do
  defstruct nick:               "",
            name:               "",
            send_pid:           0,
            time_last_pong:     :os.system_time(:seconds),
            connect_time:       :os.system_time(:seconds),
            authstage:          0,
            channels:           [] # List of channel names as strings

  def next_pong?(user) do
    case Map.fetch(user, :time_last_pong) do
      {:ok, last_pong} -> last_pong + 300 # 5 minutes after last pong
      :error -> :error
    end
  end

  def has_full_cmd_access?(user) do
    user.nick != "" && user.name != ""
  end
end
