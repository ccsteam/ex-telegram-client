defmodule TgClient.Api.CommandHandler do
  @moduledoc """
  Module for command accept, execute and handle its result.
  """
  @available_commands ["dialog_list", "contact_list", "msg", "history",
                       "create_secret_chat", "status_online", "get_self",
                       "main_session"]

  @doc """
  Extract command, params and socket from options and execute command
  """
  @spec handle_command(Keyword.t) :: {:ok, String.t} | {:error, atom}
  def handle_command(opts) do
    command = Keyword.get(opts, :command)
    params = Keyword.get(opts, :params, [])
    socket = Keyword.get(opts, :socket)
    return_response = Keyword.get(opts, :return_response)
    execute_command(command, params, socket)
    if return_response, do: handle_response(socket, [])
  end

  defp execute_command(command, params, socket)
      when command in @available_commands do
    request = Enum.join([command] ++ params, " ")
    send_request(request, socket)
  end
  defp execute_command(_command, _params, _socket) do
    {:error, :bad_command}
  end

  defp send_request(request, socket) do
    :gen_tcp.send(socket, "#{request} \n")
  end

  defp handle_response(socket, []) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, packet} ->
        [_ | response] = String.split(packet, "\n")
        response = Enum.join(response, "\n")
        {:ok, handle_response(socket, [response])}
      {:error, :timeout} ->
        {:error, :timeout}
    end
  end
  defp handle_response(socket, acc) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, response} ->
        handle_response(socket, acc ++ [response])
      {:error, :timeout} ->
        format_response(acc)
    end
  end

  defp format_response(response) do
    response
    |> List.replace_at(length(response)-1, List.last(response) |> String.split("\n\n") |> hd)
    |> Enum.join("")
  end

end
