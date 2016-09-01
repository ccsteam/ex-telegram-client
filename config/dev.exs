use Mix.Config

config :logger, level: :debug

config :tg_client,
  daemon: "/usr/local/telegram-cli",
  key: "/usr/local/share/telegram-cli/tg-server.pub",
  session_env_path: "/tmp/telegram-cli/sessions",
  port_range: 2000..4000
