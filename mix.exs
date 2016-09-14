defmodule TgClient.Mixfile do
  use Mix.Project

  def project do
    [app: :tg_client,
     version: "0.1.2",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     aliases: aliases(),
     description: description(),
     package: package()]
  end

  def application do
    [
      mod: {TgClient, []},
      applications: [:porcelain, :poolboy, :gproc]
    ]
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev},
     {:porcelain, "~> 2.0"},
     {:gproc, "~> 0.5.0"},
     {:poison, "~> 2.0"},
     {:poolboy, "~> 1.5"},]
  end

  defp aliases do
    []
  end

  defp description do
    "A Elixir wrapper that communicates with the Telegram-CLI."
  end

  defp package do
    [name: :tg_client,
     files: ["lib", "mix.exs"],
     maintainers: ["Andrey Noskov", "Alexander Malaev"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/ccsteam/ex-telegram-client"}]
  end
end
