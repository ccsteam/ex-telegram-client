use Mix.Config

config :logger, level: :debug

config :tg_client,
  event_handler: {TgClient.EventHandler, size: 10, max_overflow: 0}
