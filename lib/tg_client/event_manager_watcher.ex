defmodule TgClient.EventManagerWatcher do
  use GenServer
  alias TgClient.Utils

  @doc """
    starts the GenServer, this should be done by a Supervisor to ensure
    restarts if it itself goes down
  """
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  @doc """
    Push event to GenEvent handler
  """
  def push_event(pid, event) do
    GenServer.call(pid, {:push_event, event})
  end

  @doc """
    inits the GenServer by starting a new handler
  """
  def init(_args) do
    start_manager
  end

  @doc """
    inits the GenServer by starting a new handler
  """
  def handle_call({:push_event, event}, _from, manager) do
    GenEvent.sync_notify(manager, event)
    {:reply, :ok, manager}
  end

  @doc """
    handles EXIT messages from the GenEvent handler and restarts it
  """
  def handle_info({:gen_event_EXIT, _handler, _reason}, _manager) do
    {:ok, manager} = start_manager
    {:noreply, manager}
  end

  @doc """
    Starts a GenEvent manager
  """
  defp start_manager do
    {:ok, manager} = GenEvent.start_link([])
    add_handler(manager)
  end

  @doc """
    Add mon handler to GenEvent manager
  """
  defp add_handler(manager) when is_pid(manager) do
    case GenEvent.add_mon_handler(manager, Utils.event_handler_mod, []) do
      :ok ->
        {:ok, manager}
      {:error, reason}  ->
        {:stop, reason}
    end
  end

end
