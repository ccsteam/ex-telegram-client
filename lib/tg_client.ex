defmodule TgClient do
  use Application
  alias TgClient.Utils

  ### Application callbacks

  def start(_type, _args) do
    children = Utils.supervisor_spec

    opts = [strategy: :one_for_one, name: TgClient.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
