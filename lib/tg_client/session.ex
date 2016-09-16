defmodule TgClient.Session do
  @moduledoc """
  Worker for dealing with telegram-cli session.
  """
  use GenServer

  alias Porcelain.Process, as: Proc
  alias TgClient.{Utils, Connection, PortManager}
  alias TgClient.Event.ManagerWatcher

  @doc false
  defmodule State do
    defstruct proc: nil,
              status: :connecting,
              phone: nil,
              port: nil,
              socket: nil
  end
  @type state :: %State{
    proc: %Proc{} | nil,
    status: :connecting | :waiting_for_confirmation | :waiting_for_password | :connected,
    phone: non_neg_integer | String.t | nil,
    port: non_neg_integer | nil,
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
    case PortManager.get_free_port do
      {:ok, port} ->
        proc = Porcelain.spawn_shell(Utils.command(phone, port),
                                    in: :receive, out: {:send, self()})
        state = %State{port: port, phone: phone, proc: proc}
        connect(port)
        :erlang.send_after(1000, self(), {:check_connect, port})
        {:ok, state}
      {:error, error} ->
        {:stop, error}
    end
  end

  def handle_call(:current_status, _from, state) do
    {:reply, {:ok, state.status}, state}
  end
  def handle_call({:send_command, command, params}, _from, %{status: status} = state)
      when status in [:connected] do
    result = GenServer.call(Utils.connection_name(state.port), {:send_command, command, params})
    {:reply, result, state}
  end
  def handle_call(_, _from, state) do
    {:reply, {:error, :bad_call}, state}
  end

  def handle_cast({:confirm, code}, %{status: status} = state)
      when status in [:waiting_for_confirmation] do
    Proc.send_input(state.proc, "#{code}\n")
    :erlang.send_after(500, self(), {:check_connect, state.port})

    {:noreply, state}
  end
  def handle_cast({:put_password, password}, %{status: status} = state)
      when status in [:waiting_for_password] do
    Proc.send_input(state.proc, "#{password}\n")
    :erlang.send_after(500, self(), {:check_connect, state.port})

    {:noreply, state}
  end
  def handle_cast(_, state) do
    {:noreply, state}
  end

  def handle_info({:connect, port}, state) do
    {:ok, _pid} = Connection.start_link(port)
    {:ok, {:bound, _port}} = PortManager.bind_port(port)

    {:noreply, state}
  end
  def handle_info({:check_connect, port}, state) do
    with {:ok, response} <- GenServer.call(Utils.connection_name(port),
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

  def terminate(_reason, %{port: _port} = _state) do
    #PortManager.release_port(port)
    :ok
  end

  defp connect(port) do
    {:ok, _pid} = Connection.start_link(port)
    {:ok, {:bound, _port}} = PortManager.bind_port(port)
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
