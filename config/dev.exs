use Mix.Config

config :logger, level: :debug

config :tg_client,
  event_handler: {TgClient.Event.Handler, size: 10, max_overflow: 0}
