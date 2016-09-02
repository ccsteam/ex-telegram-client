defmodule TgClient do
  use Application
  alias TgClient.Utils

  ### Application callbacks

  def start(_type, _args) do
    children = Utils.supervisor_spec ++ Utils.event_manager_pool_spec

    opts = [strategy: :one_for_one, name: TgClient.Supervisor]
    {:ok, _pid} = Supervisor.start_link(children, opts)
  end

end
