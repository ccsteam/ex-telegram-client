defmodule TgClient.EventHandler do
  use GenEvent

  require Logger

  ### GenEvent Callbacks

  @doc false
  def handle_event(event, state) do
    Logger.debug "Unknown Event: " <> inspect(event)
    {:ok, state}
  end
end
