defmodule Latch.MixProject do
  use Mix.Project

  def project do
    [
      app: :latch,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "atproto OAuth client library for Elixir",
      package: package(),
      docs: docs()
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

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:jose, "~> 1.11"},
      {:jason, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:mimic, "~> 2.3", only: :test},
      {:nimble_options, "~> 1.1"},
      {:ex_doc, "~> 0.34", only: :dev}
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

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Tangled" => "https://tangled.org/jola.dev/latch/",
        "GitHub" => "https://github.com/joladev/latch"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
