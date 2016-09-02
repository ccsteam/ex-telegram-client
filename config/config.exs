use Mix.Config

config :tg_client,
  daemon: "/usr/local/telegram-cli",
  key: "/usr/local/share/telegram-cli/tg-server.pub",
  session_env_path: "/tmp/telegram-cli/sessions",
  port_range: 2000..4000,
  default_pool_size: 5,
  default_pool_max_overflow: 10,
  pool_name: :event_handler,
  event_handler: {}

import_config "#{Mix.env}.exs"
