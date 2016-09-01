defmodule TgClient do
  use Application

  defmodule Settings do
    defstruct phone: nil, port: nil
  end

  @type settings :: %Settings{
    phone: non_neg_integer | nil,
    port: non_neg_integer | nil
  }

  ### Application callbacks

  def start(_type, _args) do
    #children = Utils.event_handlers_spec

    # opts = [strategy: :one_for_one, name: TgClient.Supervisor]
    # Supervisor.start_link(children, opts)
  end

end
