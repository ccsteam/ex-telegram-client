defmodule TgClient.Utils do
  @moduledoc """
  Module with usefull functions.
  """
  alias TgClient.{PortManager, EventManagerWatcher}

  import Supervisor.Spec, only: [worker: 3]

  @type gproc_name :: {atom, atom, {atom, atom, {atom, String.t}}}

  @doc """
  Return command for start telegram-cli
  """
  @spec command(non_neg_integer, non_neg_integer) :: String.t
  def command(phone, port) do
    init_session_env(phone)
    "export TELEGRAM_HOME=#{session_env_path(phone)} && #{daemon} #{cli_arguments} -P #{port}"
  end

  defp cli_arguments do
    ["-k #{server_key}", "-C", "--json"] |> Enum.join(" ")
  end

  defp init_session_env(phone) do
    unless File.exists?(session_env_path(phone)) do
      File.mkdir_p("#{session_env_path(phone)}/.telegram-cli")
    end
  end

  @doc """
  Creates unique name for session process based on user phone
  """
  @spec session_name(non_neg_integer) :: gproc_name
  def session_name(phone) do
     phone |> Integer.to_string |> via_tuple(:session)
  end

  @doc """
  Creates unique name for connection process based on port number
  """
  @spec connection_name(non_neg_integer) :: gproc_name
  def connection_name(port) do
     port |> Integer.to_string |> via_tuple(:connection)
  end

  ### Internal functions

  @spec via_tuple(String.t, atom) :: gproc_name
  defp via_tuple(worker_name, worker_type) do
    {:via, :gproc, {:n, :l, {worker_type, worker_name}}}
  end

  @doc """
  Return Supervisor.Spec for general workers
  """
  @spec supervisor_spec :: [Supervisor.spec]
  def supervisor_spec do
    [
      worker(PortManager, [], [])
    ]
  end

  @doc """
  Return Supervisor.Spec for event workers
  """
  @spec event_manager_pool_spec :: [Supervisor.spec]
  def event_manager_pool_spec do
    {_handler, opts} = event_handler()
    size = Keyword.get(opts, :size, default_pool_size())
    max_overflow = Keyword.get(opts, :max_overflow, default_pool_max_overflow())
    [poolboy_spec(pool_name(), EventManagerWatcher, size, max_overflow)]
  end

  defp poolboy_spec(name, handler, size, max_overflow) do
    poolboy_config = [
      {:name, {:local, name}},
      {:worker_module, handler},
      {:size, size},
      {:max_overflow, max_overflow}
    ]

    :poolboy.child_spec(name, poolboy_config, [])
  end

  @doc """
  Return event handler module
  """
  @spec event_handler_mod :: module
  def event_handler_mod do
    {mod, _opts} = event_handler
    mod
  end

  @doc """
  Return pool name
  """
  @spec pool_name :: atom
  def pool_name do
    Application.get_env(:tg_client, :pool_name)
  end

  @doc """
  Return ports range
  """
  @spec port_range :: Range.t
  def port_range do
    Application.get_env(:tg_client, :port_range)
  end

  defp event_handler do
    Application.get_env(:tg_client, :event_handler)
  end

  defp default_pool_size do
    Application.get_env(:tg_client, :default_pool_size)
  end

  defp default_pool_max_overflow do
    Application.get_env(:tg_client, :default_pool_max_overflow)
  end

  defp session_env_path(phone) do
    "#{session_env_path}/#{phone_hash(phone)}"
  end
  defp session_env_path do
    Application.get_env(:tg_client, :session_env_path)
  end

  defp phone_hash(phone) do
    :crypto.hash(:md5, Integer.to_string(phone)) |> Base.encode16
  end

  defp daemon do
    Application.get_env(:tg_client, :daemon)
  end

  defp server_key do
    Application.get_env(:tg_client, :key)
  end

end
