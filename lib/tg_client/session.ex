defmodule TgClient.Session do
  use GenServer

  alias Porcelain.Process, as: Proc
  alias TgClient.{Utils, Connection}

  require Logger

  defmodule State do
    defstruct proc: nil,
              status: :init,
              phone: nil,
              port: nil,
              socket: nil
  end

  ### API

  def start_link(%{phone: phone} = settings) do
    GenServer.start_link(__MODULE__, settings, name: Utils.session_name(phone))
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

  def init(settings) do
    proc = Porcelain.spawn_shell(Utils.command(settings.phone, settings.port),
                                in: :receive, out: {:send, self()})
    state = %State{port: settings.port, phone: settings.phone, proc: proc}
    send self(), {:connect, settings.port}

    {:ok, state}
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
    {:ok, pid} = Connection.start_link(port)
    Process.monitor(pid)

    {:noreply, %{state | status: :connected}}
  end

  def handle_info({_pid, :data, :out, data}, state) do
    #Logger.debug "Data received: #{inspect data}"
    {:ok, lines, rest} = handle_data(data)

    #Logger.debug "Data handled: #{inspect lines}"
    #Logger.debug "Data rest: #{inspect rest}"

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
  def handle_info(msg, state) do
    Logger.debug inspect msg
    {:noreply, state}
  end


  def handle_data(data) do
    handle_data(data, [], [])
  end

  def handle_data("\r\e[K" <> rest, line, acc) do
    handle_data(rest, line, acc)
  end
  def handle_data("\n" <> rest, line, acc) do
    handle_data(rest, [], [Enum.reverse(line)|acc])
  end

  def handle_data(<<char>> <> rest, line, acc) do
    handle_data(rest, [char|line], acc)
  end

  def handle_data("", rest, acc) do
    {:ok, Enum.reverse(acc), Enum.reverse(rest)}
  end
end
