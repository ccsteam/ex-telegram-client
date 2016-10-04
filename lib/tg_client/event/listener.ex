defmodule TgClient.Event.Listener do
  use GenServer

  alias TgClient.Utils
  alias TgClient.Event.ManagerWatcher

  require Logger

  def start_link(socket, socket_path) do
    GenServer.start_link(__MODULE__, socket, name: Utils.listener_name(socket_path))
  end

  def init(socket) do
    :erlang.send_after(1000, self(), :receive)
    {:ok, %{socket: socket}}
  end

  def handle_info(:receive, %{socket: socket} = state) do
    handle_response(socket, [])
    {:noreply, state}
  end

  defp handle_response(socket, []) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, packet} ->
        handle_response(socket, [packet])
      {:error, :timeout} ->
        :erlang.send_after(500, self(), :receive)
    end
  end
  defp handle_response(socket, acc) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, response} ->
        handle_response(socket, acc ++ [response])
      {:error, :timeout} ->
        events = format_response(acc)
        Enum.each(events, &send_event/1)
        :erlang.send_after(500, self(), :receive)
    end
  end

  defp format_response(acc) do
    acc
    |> Enum.join("")
    |> String.split("\n\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&remove_header/1)
  end

  defp remove_header("ANSWER" <> response) do
    [_ | result] = String.split(response, "\n")
    Enum.join(result, "\n")
  end
  defp remove_header(response), do: response

  defp send_event(event) do
    spawn fn ->
      :poolboy.transaction(Utils.pool_name(), fn(pid) ->
        ManagerWatcher.push_event(pid, Poison.decode!(event))
      end)
    end
  end
end
