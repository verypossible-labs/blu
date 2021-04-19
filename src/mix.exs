defmodule Blu.MixProject do
  use Mix.Project

  def project do
    [
      package: package(),
      app: :blu,
      deps: deps(),
      description: description(),
      elixir: "~> 1.11",
      source_url: "https://github.com/verypossible-labs/blu",
      start_permanent: Mix.env() == :prod,
      version: "0.1.0"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.23.0", only: [:dev], runtime: false},
      {:hook, "~> 0.3.0"},
      {:harald, path: "~/vp/labs/harald/src"}
    ]
  end

  defp description do
    """
    An Elixir Bluetooth host library.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/verypossible-labs/blu"}
    ]
  end
end
