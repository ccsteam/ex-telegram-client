defmodule TgClient.PortManager do
  use GenServer

  ### API

  def start_link do
    start_link(MapSet.new)
  end
  def start_link(ports) do
    GenServer.start_link(__MODULE__, ports, name: __MODULE__)
  end

  def bind_port do
    {:ok, port} = get_free_port
    bind_port(port)
  end
  def bind_port(port) do
    GenServer.call(__MODULE__, {:bind_port, port})
  end

  def get_free_port do
    GenServer.call(__MODULE__, :get_free_port)
  end

  def release_port(port) do
    GenServer.cast(__MODULE__, {:release, port})
  end

  ### GenServer Callbacks

  def init(ports) do
    Task.async(&release_all_system_ports/0)
    {:ok, ports}
  end

  def handle_call({:bind_port, port}, _from, busy_ports) do
    if MapSet.member?(busy_ports, port) do
      {:reply, {:error, {:already_bound, port}}, busy_ports}
    else
      {:reply, {:ok, {:bound, port}}, MapSet.put(busy_ports, port)}
    end
  end
  def handle_call(:get_free_port, _from, busy_ports) do
    port = Stream.filter(port_range, &(not &1 in busy_ports)) |> Enum.take(1) |> List.first
    if port do
      {:reply, {:ok, port}, busy_ports}
    else
      {:reply, {:error, :no_free_ports}, busy_ports}
    end
  end

  def handle_cast({:release_port, port}, busy_ports) do
    {:noreply, MapSet.delete(busy_ports, port)}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ### Internal functions

  defp release_all_system_ports do
    port_range
    |> Stream.filter(&system_port_bound?/1)
    |> Enum.each(&kill_system_port/1)
  end

  defp port_range do
    Application.get_env(:tg_client, :port_range)
  end

  defp system_port_bound?(port) do
    !check_system_port(port) == []
  end
  defp check_system_port(port) do
    "lsof -i:#{port}" |> String.to_charlist |> :os.cmd
  end
  defp kill_system_port(port) do
    "kill -9 $(lsof -t -i:#{port})"
    |> String.to_charlist
    |> :os.cmd
  end

end
