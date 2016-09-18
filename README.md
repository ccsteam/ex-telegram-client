# Telegram Client

A Elixir wrapper that communicates with the Telegram-CLI.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

* Add `tg_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:tg_client, "~> 0.1.0"]
end
```

* Ensure `tg_client` is started before your application:

```elixir
def application do
  [applications: [:tg_client]]
end
```

## Usage

* Write your own EventHandler module.

```elixir
defmodule EventHandler do
  use GenEvent
  require Logger

  def handle_event(event, state) do
    Logger.debug "Unknown Event: " <> inspect(event)
    {:ok, state}
  end
end
```

* Set config.

```elixir
config :tg_client,
  daemon: "/usr/local/telegram-cli",
  key: "/usr/local/share/telegram-cli/tg-server.pub",
  session_env_path: "/tmp/telegram-cli/sessions",
  default_pool_size: 5,
  default_pool_max_overflow: 10,
  pool_name: :event_handler,
  event_handler: {TgClient.Event.Handler, size: 10, max_overflow: 10}
```

## Authorization

* Start session

```elixir
{:ok, _pid} = TgClient.Session.start_link(79251008050)
```

* Start session under Supervisor

```elixir
{:ok, _pid} = TgClient.start_session(79251008050)
```

* Check session status

```elixir
{:ok, status} = TgClient.Session.current_status(79251008050)
```

when status in [:init, :waiting_for_confirmation, :waiting_for_password, :connected]

* Confirm

```elixir
:ok = TgClient.Session.confirm(79251008050, 22284)
```

has effect only if status is :waiting_for_confirmation

* Put password

```elixir
:ok = TgClient.Session.put_password(79251008050, "secret_password")
```

has effect only if status is :waiting_for_password

## Commands

all commands has effect only if status is :connected

* Dialog list

```elixir
{:ok, response} = TgClient.Session.send_command(79251008050, "dialog_list", [])
```

when response is:

```json
[
   {
      \"admin\":{
         \"id\":\"$01000000000000000000000000000000\",
         \"peer_type\":\"user\",
         \"peer_id\":0,
         \"print_name\":\"user#0\"
      },
      \"id\":\"$02000000e47cd0010000000000000000\",
      \"flags\":1,
      \"peer_type\":\"chat\",
      \"peer_id\":30440676,
      \"print_name\":\"йцу\",
      \"title\":\"йцу\",
      \"members_num\":3
   },
   {
      \"id\":\"$010000005d7c21050ddae73d36d42000\",
      \"peer_type\":\"user\",
      \"flags\":196609,
      \"peer_id\":86080605,
      \"first_name\":\"Собакин\",
      \"print_name\":\"Собакин_Кот\",
      \"when\": \"2016-08-31 22:45:43\",
      \"phone\":\"7800400300\",
      \"last_name\":\"Кот\"
   }
]
```

* Contact list

```elixir
{:ok, response} = TgClient.Session.send_command(79251008050, "contact_list", [])
```

when response is:

```json
[
   {
      \"id\":\"$01000000946c090ddf6ba9457ce8c248\",
      \"peer_type\":\"user\",
      \"flags\":196609,
      \"peer_id\":218721428,
      \"first_name\":\"Дмитрий\",
      \"print_name\":\"Дмитрий_Негру\",
      \"when\": \"2016-05-20 18:12:40\",
      \"phone\":\"7800400300\",
      \"last_name\":\"Негру\"
   }
]
```

* Send message [peer, text]

```elixir
{:ok, response} = TgClient.Session.send_command(79251008050, "msg", ["$010000001az3av003d8059e845e429e1", "hello"])
```

when response is:

```json
{
   \"result\":\"SUCCESS\"
}
```

* Message history [peer, limit, offset]

```elixir
{:ok, response} = TgClient.Session.send_command(79251008050, "history", ["$010000001az3av003d8059e845e429e1", "5", "0"])
```

when response is:

```json
[
   {
      \"text\":\"hello\",
      \"unread\":true,
      \"event\":\"message\",
      \"id\":\"010000001ae3ab00496c0100000000003d8059e845e429e1\",
      \"from\":{
         \"username\":\"badrequest\",
         \"id\":\"$010000001ae3ab003d8059e845e429e1\",
         \"peer_type\":\"user\",
         \"flags\":524289,
         \"peer_id\":11264794,
         \"first_name\":\"Andrew\",
         \"print_name\":\"Andrew_Noskov\",
         \"when\":\"2016-09-01 14:06:33\",
         \"phone\":\"79251008050\",
         \"last_name\":\"Noskov\"
      },
      \"flags\":16643,
      \"to\":{
         \"username\":\"badrequest\",
         \"id\":\"$010000001ae3ab003d8059e845e429e1\",
         \"peer_type\":\"user\",
         \"flags\":524289,
         \"peer_id\":11264794,
         \"first_name\":\"Andrew\",
         \"print_name\":\"Andrew_Noskov\",
         \"when\":\"2016-09-01 14:06:33\",
         \"phone\":\"79251008050\",
         \"last_name\":\"Noskov\"
      },
      \"out\":true,
      \"service\":false,
      \"date\":1472727693
   }
]
```

* Create secret chat [peer]

```elixir
{:ok, response} = TgClient.Session.send_command(79251008050, "create_secret_chat", ["$010000001az3av003d8059e845e429e1"])
```

when response is:

```json
{
   \"flags\":1,
   \"print_name\":\"!_Polya\",
   \"id\":\"$010000001az3av003d8059e845e429e1\",
   \"peer_type\":\"encr_chat\",
   \"peer_id\":1901915394,
   \"user\":{
      \"flags\":196609,
      \"id\":\"$010000001az3av003d8059e845e429e1\",
      \"print_name\":\"Polya\",
      \"peer_type\":\"user\",
      \"last_name\":\"\",
      \"peer_id\":65370635,
      \"first_name\":\"Polya\",
      \"when\":\"2016-09-01 13:35:34\",
      \"phone\":\"79251008050\"
   }
}
```

## Configuration

* Set config or pass default attributes

```elixir
config :tg_client,
  daemon: "/usr/local/telegram-cli",
  key: "/usr/local/share/telegram-cli/tg-server.pub",
  session_env_path: "/tmp/telegram-cli/sessions",
  default_pool_size: 5,
  default_pool_max_overflow: 10,
  pool_name: :event_handler,
  event_handler: {TgClient.Event.Handler, size: 10, max_overflow: 10}
```
