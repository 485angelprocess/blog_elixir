defmodule AnnabelleBlog.MixProject do
  use Mix.Project

  def project do
    [
      app: :annabelle_blog,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases() do
    [
      "site.build": ["build", "tailwind default --minify", "esbuild default --minify"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
    	{:nimble_publisher, "~> 1.1.1", runtime: false},
      {:makeup_elixir, ">= 0.0.0", runtime: false},
      {:makeup_erlang, ">= 0.0.0", runtime: false},
      {:phoenix_live_view, "~> 1.0.5"},
      {:esbuild, ">= 0.0.0"},
      {:tailwind, ">= 0.0.0"}  
    ]
  end
end
