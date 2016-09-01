defmodule TgClient.CommandHandler do
  @available_commands ["dialog_list", "contact_list", "msg", "history",
                       "create_secret_chat"]

  def handle_command(opts) do
    command = Keyword.get(opts, :command)
    params = Keyword.get(opts, :params, [])
    socket = Keyword.get(opts, :socket)
    execute_command(command, params, socket)
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
    handle_response(socket, [])
  end

  defp handle_response(socket, []) do
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, packet} ->
        [_ | response] = String.split(packet, "\n")
        response = Enum.join(response, "\n")
        {:ok, handle_response(socket, [response])}
      {:error, :timeout} ->
        {:error, :timeout}
    end
  end
  defp handle_response(socket, acc) do
    case :gen_tcp.recv(socket, 0, 1000) do
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
