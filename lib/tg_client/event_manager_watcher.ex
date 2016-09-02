defmodule TgClient.EventManagerWatcher do
  @moduledoc """
  Worker for creation/monitoring GenEvent manager and registration event handler.
  """
  use GenServer

  alias TgClient.Utils

  @doc """
    Starts EventManagerWatcher
  """
  @spec start_link(any) :: GenServer.on_start
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  @doc """
    Push event to GenEvent handler
  """
  @spec push_event(pid, map) :: :ok | {:error, term}
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
    Send sync notification to handler
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

  defp start_manager do
    {:ok, manager} = GenEvent.start_link([])
    add_handler(manager)
  end

  defp add_handler(manager) when is_pid(manager) do
    case GenEvent.add_mon_handler(manager, Utils.event_handler_mod, []) do
      :ok ->
        {:ok, manager}
      {:error, reason}  ->
        {:stop, reason}
    end
  end

end
