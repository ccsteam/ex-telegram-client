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


  ### Internal functions

  defp port_range do
    Application.get_env(:tg_client, :port_range)
  end

end
