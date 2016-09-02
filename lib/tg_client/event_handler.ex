defmodule TgClient.EventHandler do
  use GenEvent
  require Logger

  ### GenEvent Callbacks

  def handle_event(event, state) do
    Logger.debug "Unknown Event: " <> inspect(event)
    {:ok, state}
  end
end
