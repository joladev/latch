defmodule Latch.MixProject do
  use Mix.Project

  def project do
    [
      app: :latch,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:jose, "~> 1.11"},
      {:jason, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "test --warnings-as-errors",
        "credo --strict"
      ]
    ]
  end
end
