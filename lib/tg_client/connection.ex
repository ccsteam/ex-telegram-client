defmodule TgClient.Connection do
  @moduledoc """
  Connection with Telegram-CLI TCP server.
  """
  use GenServer

  alias TgClient.Utils
  alias TgClient.Api.CommandHandler

  require Logger

  @doc false
  defmodule State do
    defstruct socket_path: "1234",
              failure_count: 0,
              socket: nil
  end
  @type state :: %State{
    socket_path: String.t,
    failure_count: non_neg_integer,
    socket: port | nil
  }

  @retry_interval 1000
  @max_retries 10

  ### API

  @doc """
  Starts connection with socket_path
  """
  @spec start_link(non_neg_integer) :: GenServer.on_start
  def start_link(socket_path) do
    GenServer.start_link(__MODULE__, socket_path, name: Utils.connection_name(socket_path))
  end

  ### GenServer Callbacks

  def init(socket_path) do
    state = %State{socket_path: socket_path}
    case :afunix.connect(to_char_list(socket_path), [:binary, active: :false]) do
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
      case :afunix.connect(to_char_list(state.socket_path), [:binary, active: :false]) do
        {:ok, socket} ->
          {:noreply, %{state | failure_count: 0, socket: socket}}
        {:error, _reason} ->
          {:noreply, %{state | failure_count: failure_count + 1}, @retry_interval}
      end
    else
      {:stop, :max_retry_exceeded, state}
    end
  end

  def terminate(reason, %{socket_path: socket_path} = state) do
    Logger.debug("Connection with socket_path: #{socket_path} terminated with reason: #{inspect reason}")
    :ok
  end

end
