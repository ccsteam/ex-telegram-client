defmodule TgClient.Session do
  use GenServer

  alias Porcelain.Process, as: Proc
  alias TgClient.{Utils, Connection, PortManager}

  require Logger

  defmodule State do
    defstruct proc: nil,
              status: :init,
              phone: nil,
              port: nil,
              socket: nil
  end

  ### API

  def start_link(phone) do
    GenServer.start_link(__MODULE__, phone, name: Utils.session_name(phone))
  end

  def current_status(phone) do
    GenServer.call(Utils.session_name(phone), :current_status)
  end

  def send_command(phone, command, params) do
    GenServer.call(Utils.session_name(phone), {:send_command, command, params})
  end

  def confirm(phone, code) do
    GenServer.cast(Utils.session_name(phone), {:confirm, code})
  end

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
        send self(), {:connect, port}
        {:ok, state}
      {:error, error} ->
        {:stop, error}
    end
  end

  def handle_call(:current_status, _from, state) do
    {:reply, state.status, state}
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
    {:noreply, %{state | status: :connected}}
  end
  def handle_cast({:put_password, password}, %{status: status} = state)
      when status in [:waiting_for_password] do
    Proc.send_input(state.proc, "#{password}\n")
    {:noreply, %{state | status: :connected}}
  end
  def handle_cast(_, state) do
    {:noreply, state}
  end

  def handle_info({:connect, port}, state) do
    {:ok, _pid} = Connection.start_link(port)
    {:ok, {:bound, _port}} = PortManager.bind_port(port)

    {:noreply, %{state | status: :connected}}
  end

  def handle_info({_pid, :data, :out, data}, state) do
    {:ok, lines, rest} = handle_data(data)
    data = charlist_to_string(lines)
    #Logger.debug "Data handled: #{inspect data}"

    try do
      send_event(Poison.Parser.parse!(data))
    rescue
      Poison.SyntaxError -> :skip
    end
    case rest do
      'phone number: ' ->
        Proc.send_input(state.proc, "#{state.phone} \n")
        {:noreply, state}
      'code (\'CALL\' for phone code): ' ->
        {:noreply, %{state | status: :waiting_for_confirmation}}
      'password: ' ->
        {:noreply, %{state | status: :waiting_for_password}}
      _ ->
        {:noreply, state}
    end
  end
  def handle_info(_msg, state) do
    {:noreply, state}
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
    GenEvent.notify(:event_handler, event)
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
