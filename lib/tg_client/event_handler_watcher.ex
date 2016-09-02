defmodule TgClient.EventHandlerWatcher do
  use GenServer
  alias TgClient.Utils

  @doc """
    starts the GenServer, this should be done by a Supervisor to ensure
    restarts if it itself goes down
  """
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
    inits the GenServer by starting a new handler
  """
  def init(_args) do
    start_handler
  end

  @doc """
    handles EXIT messages from the GenEvent handler and restarts it
  """
  def handle_info({:gen_event_EXIT, _handler, _reason}, event_handler_pid) do
    {:ok, event_handler_pid} = start_handler(event_handler_pid)
    {:noreply, event_handler_pid}
  end

  @doc """
    starts a GenEvent process
  """
  defp start_handler do
    {:ok, event_handler_pid} = GenEvent.start_link(name: :event_handler)
    start_handler(event_handler_pid)
  end

  @doc """
    starts a new handler listening for events on `logger_pid`
  """
  defp start_handler(event_handler_pid) do
    case GenEvent.add_mon_handler(event_handler_pid, Utils.event_handler_mod, []) do
      :ok ->
        {:ok, event_handler_pid}
      {:error, reason}  ->
        {:stop, reason}
    end
  end
end
