defmodule TgClient.Session do
  @moduledoc """
  Worker for dealing with telegram-cli session.
  """
  use GenServer

  alias Porcelain.Process, as: Proc
  alias TgClient.{Utils, Connection}
  alias TgClient.Event.ManagerWatcher

  require Logger

  @doc false
  defmodule State do
    defstruct proc: nil,
    status: :offline,
    phone: nil,
    socket: nil,
    socket_path: nil
  end
  @type state :: %State{
    proc: %Proc{} | nil,
    status: :offline | :waiting_for_confirmation | :waiting_for_password | :connected,
    phone: non_neg_integer | String.t | nil,
    socket_path: String.t | nil,
    socket: port | nil
  }

  ### API

  @doc """
  Starts a session with phone
  """
  @spec start_link(non_neg_integer | String.t) :: GenServer.on_start
  def start_link(phone) do
    GenServer.start_link(__MODULE__, phone, name: Utils.session_name(phone))
  end

  @doc """
  Connects a session with phone
  """
  @spec connect(non_neg_integer | String.t) :: {:ok, atom}
  def connect(phone) do
    GenServer.call(Utils.session_name(phone), :connect)
  end

  @doc """
  Return current session status
  """
  @spec current_status(non_neg_integer | String.t) :: {:ok, atom}
  def current_status(phone) do
    GenServer.call(Utils.session_name(phone), :current_status)
  end

  @doc """
  Send request to TCP connection
  """
  @spec send_command(non_neg_integer | String.t, String.t, List.t) :: {:ok, String.t} | {:error, atom}
  def send_command(phone, command, params) do
    GenServer.call(Utils.session_name(phone), {:send_command, command, params})
  end

  @doc """
  Put confirmation code to stdio
  """
  @spec confirm(non_neg_integer | String.t, non_neg_integer) :: atom
  def confirm(phone, code) do
    GenServer.cast(Utils.session_name(phone), {:confirm, code})
  end

  @doc """
  Put password to stdio
  """
  @spec put_password(non_neg_integer | String.t, non_neg_integer) :: atom
  def put_password(phone, password) do
    GenServer.cast(Utils.session_name(phone), {:put_password, password})
  end

  ### GenServer Callbacks

  def init(phone) do
    {:ok, %State{socket_path: nil, phone: phone, proc: nil}}
  end

  def handle_call(:connect, _from, %{phone: phone} = state) do
    socket_path = Utils.connection_socket_path(phone)

    Logger.debug("Starting telegram-cli: #{Utils.command(phone, socket_path)}")
    proc = Porcelain.spawn_shell(Utils.command(phone, socket_path),
       in: :receive, out: {:send, self()})

    Logger.debug("Started telegram-cli proccess: #{inspect proc}")

    state = %State{socket_path: socket_path, phone: phone, proc: proc}

    start_connection(socket_path)
    :erlang.send_after(1000, self(), {:check_connect, socket_path})

    {:reply, {:ok, :connected}, state}
  end

  def handle_call(:current_status, _from, state) do
    {:reply, {:ok, state.status}, state}
  end
  def handle_call({:send_command, command, params}, _from, %{status: status} = state)
  when status in [:connected] do
    result = GenServer.call(Utils.connection_name(state.socket_path), {:send_command, command, params})
    {:reply, result, state}
  end
  def handle_call(_, _from, state) do
    {:reply, {:error, :bad_call}, state}
  end

  def handle_cast({:confirm, code}, %{status: status} = state)
  when status in [:waiting_for_confirmation] do
    Proc.send_input(state.proc, "#{code}\n")
    :erlang.send_after(500, self(), {:check_connect, state.socket_path})

    {:noreply, state}
  end
  def handle_cast({:put_password, password}, %{status: status} = state)
  when status in [:waiting_for_password] do
    Proc.send_input(state.proc, "#{password}\n")
    :erlang.send_after(500, self(), {:check_connect, state.socket_path})

    {:noreply, state}
  end
  def handle_cast(_, state) do
    {:noreply, state}
  end

  def handle_info({:connect, socket_path}, state) do
    {:ok, _pid} = Connection.start_link(socket_path)

    {:noreply, state}
  end
  def handle_info({:check_connect, socket_path}, state) do
    with {:ok, response} <- GenServer.call(Utils.connection_name(socket_path),
     {:send_command, "status_online", []}),
    %{"result" => "SUCCESS"} <- Poison.decode!(response)
    do
      {:noreply, %{state | status: :connected}}
    else
      _ -> {:noreply, state}
    end
  end

  def handle_info({_pid, :data, :out, data}, state) do
    {:ok, lines, rest} = handle_data(data)
    data = charlist_to_string(lines)

    try do
      send_event(Poison.Parser.parse!(data))
      {:noreply, state}
    rescue
      Poison.SyntaxError ->
        case rest do
          'phone number: ' ->
            Proc.send_input(state.proc, "#{state.phone} \n")
            {:noreply, %{state | status: :waiting_for_confirmation}}
          'code (\'CALL\' for phone code): ' ->
            {:noreply, %{state | status: :waiting_for_confirmation}}
          'password: ' ->
            {:noreply, %{state | status: :waiting_for_password}}
          _ ->
            {:noreply, state}
        end
    end
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def terminate(_reason, %{socket_path: _socket_path} = _state) do
    :ok
  end

  defp start_connection(socket_path) do
    {:ok, _pid} = Connection.start_link(socket_path)
  end

  defp handle_data(data) do
    handle_data(data, [], [])
  end

  defp handle_data("\r\e[K" <> rest, line, acc) do
     handle_data(rest, line, acc)
  end
  defp handle_data("\n" <> rest, line, acc) do
    handle_data(rest, [], [Enum.reverse(line)|acc])
  end
  defp handle_data(<<char>> <> rest, line, acc) do
    handle_data(rest, [char|line], acc)
  end
  defp handle_data("", rest, acc) do
    {:ok, Enum.reverse(acc), Enum.reverse(rest)}
  end

  defp send_event(event) when is_map(event) do
    spawn fn ->
      :poolboy.transaction(Utils.pool_name(), fn(pid) ->
        ManagerWatcher.push_event(pid, event)
      end)
    end
  end
  defp send_event(_data) do
    :ok
  end

  defp charlist_to_string(data) when is_list(data) do
    data |> List.flatten |> Enum.map(&(<<&1>>)) |> Enum.join("")
  end
  defp charlist_to_string(data) do
    data
  end
end
