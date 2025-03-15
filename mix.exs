defmodule Accountex.MixProject do
  use Mix.Project

  def project do
    [
      app: :accountex,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      aliases: aliases(),
      deps: deps(),
      releases: [
        accountex: [
          steps: [:assemble, &copy_beacon_files/1]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Accountex.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:beacon_live_admin, "~> 0.4"},
      {:beacon, "~> 0.4"},
      {:ex_money_sql, "~> 1.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:picosat_elixir, "~> 0.2"},
      {:oban, "~> 2.0"},
      {:ash_paper_trail, "~> 0.5"},
      {:ash_oban, "~> 0.3"},
      {:ash_admin, "~> 0.13"},
      {:ash_money, "~> 0.1"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:sourceror, "~> 1.7", only: [:dev, :test]},
      {:ash, "~> 3.0"},
      {:igniter, "~> 0.5", only: [:dev, :test]},
      {:phoenix, "~> 1.7.20"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind accountex", "esbuild accountex"],
      "assets.deploy": [
        "tailwind accountex --minify",
        "esbuild accountex --minify",
        "phx.digest"
      ],
      "phx.routes": ["phx.routes", "ash_authentication.phoenix.routes"]
    ]
  end

  defp copy_beacon_files(%{path: path = release}) do
    build_path = Path.join([path, "bin", "_build"])
    File.mkdir_p!(build_path)
    
    copy_bin! = fn name, pattern, cmd ->
      case Path.wildcard(pattern) do
         [] -> 
          raise """
            #{name} binary not found in the release package.

            You should execute the following command to download it:

              #{cmd}

            Note the binary must be present in the environment where the
            release is generated, either locally or in the Dockerfile for example.
          """

        bin_path ->
          for file <- bin_path do
            File.cp!(file, Path.join(build_path, Path.basename(file)))
          end
          
      end
    end

    copy_bin!.("tailwind", "_build/tailwind-*", "mix tailwind.install --no-assets")
    copy_bin!.("esbuild", "_build/esbuild-*", "mix esbuild.install")

    File.cp(Path.join(["assets", "css", "app.css"]), Path.join(path, "app.css"))

    release

  end




end
