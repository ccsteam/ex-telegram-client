defmodule TgClient.Connection do
  @moduledoc """
  Connection with Telegram-CLI TCP server.
  """
  use GenServer

  alias TgClient.{Utils, PortManager}
  alias TgClient.Api.CommandHandler

  @doc false
  defmodule State do
    defstruct host: 'localhost',
              port: 1234,
              failure_count: 0,
              socket: nil
  end
  @type state :: %State{
    host: charlist,
    port: non_neg_integer,
    failure_count: non_neg_integer,
    socket: port | nil
  }

  @retry_interval 1000
  @max_retries 10

  ### API

  @doc """
  Starts connection with port
  """
  @spec start_link(non_neg_integer) :: GenServer.on_start
  def start_link(port) do
    GenServer.start_link(__MODULE__, port, name: Utils.connection_name(port))
  end

  ### GenServer Callbacks

  def init(port) do
    state = %State{port: port}
    case :gen_tcp.connect(state.host, state.port, [:binary, active: :false]) do
      {:ok, socket} ->
        {:ok, %{state | socket: socket}}
      {:error, _reason} ->
        {:ok, state, @retry_interval}
    end
  end

  def handle_call({:send_command, command, params}, _from, state) do
    result = CommandHandler.handle_command(command: command,
                                           params: params,
                                           socket: state.socket)
    {:reply, result, state}
  end

  def handle_info(:timeout, state = %State{failure_count: failure_count}) do
    if failure_count <= @max_retries do
      case :gen_tcp.connect(state.host, state.port, [:binary, active: :false]) do
        {:ok, socket} ->
          {:noreply, %{state | failure_count: 0, socket: socket}}
        {:error, _reason} ->
          {:noreply, %{state | failure_count: failure_count + 1}, @retry_interval}
      end
    else
      {:stop, :max_retry_exceeded, state}
    end
  end

  def terminate(_reason, %{port: port} = state) do
  #  PortManager.release_port(port)
    :ok
  end

end
