defmodule TgClient do
  use Application

  alias TgClient.{Utils, Session}
  import Supervisor.Spec, only: [worker: 3]

  ### Application callbacks

  def start(_type, _args) do
    children = Utils.supervisor_spec ++ Utils.event_manager_pool_spec

    opts = [strategy: :one_for_one, name: TgClient.Supervisor]
    {:ok, _pid} = Supervisor.start_link(children, opts)
  end

  @doc """
  Start session under Supervisor
  """
  @spec start_session(non_neg_integer | String.t) :: Supervisor.on_start_child
  def start_session(phone) do
    Supervisor.start_child(TgClient.Supervisor,
                           worker(Session, [phone], [id: Utils.session_name(phone)]))
  end

end
