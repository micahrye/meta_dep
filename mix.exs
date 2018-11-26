defmodule MetaDep.MixProject do
  use Mix.Project

  def project do
    [
      app: :meta_dep,
      version: "0.1.3",
      elixir: "~> 1.7",
      package: package(),
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_add_apps: [:mix]],
      escript: [main_module: MetaDep],
      deps: deps(),
      description: description(),
      docs: [
        main: "MetaDep",
        extras: ["README.md"]
      ]
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
      # {:ex_doc, "~> 0.19", only: :dev, runtime: false},

      # Elixir and Erlang packages used for dev and testing
      # {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      # {:chumak, "1.3.0", only: :dev, runtime: false},
      # {:jason, "1.1.2", only: :dev, runtime: false},
      # {:plug_cowboy, "~> 2.0.0", only: :dev, runtime: false},
      # {:plug, "1.7.1", only: :dev, runtime: false},
      # {:sweet_xml, "0.6.5", only: :dev, runtime: false},
      {:bunt, "0.2.0", only: :dev, runtime: false},
    ]
  end

  defp description() do
    """
    List meta information for project dependencies such as, licences, maintainers, repo links.
    """
  end

  defp package do
    [
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE"
      ],
      maintainers: ["Micah Rye"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/micahrye/meta_dep"},
    ]
  end
end
