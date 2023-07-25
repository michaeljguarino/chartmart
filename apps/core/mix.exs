defmodule Core.MixProject do
  use Mix.Project

  defp version do
    version = git_vsn()
    case Version.parse(version) do
      {:ok, %Version{pre: ["pre" <> _ | _]} = version} ->
        to_string(version)

      {:ok, %Version{pre: []} = version} ->
        to_string(version)

      {:ok, %Version{patch: patch, pre: pre} = version} ->
        to_string(%{version | patch: patch + 1, pre: ["dev" | pre]})

      :error ->
        Mix.shell().error("Failed to parse, falling back to 0.0.0")
        "0.0.0"
    end
  end

  defp git_vsn() do
    case System.cmd("git", ~w[describe --dirty=+dirty]) do
      {version, 0} ->
        String.trim_leading(String.trim(version), "v")

      {_, code} ->
        Mix.shell().error("Git exited with code #{code}, falling back to 0.0.0")

        "0.0.0"
    end
  end

  def project do
    [
      app: :core,
      version: version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Core.Application, []},
      extra_applications: [:logger, :crypto, :porcelain, :ssh]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:sentry, "8.0.6"},
      {:ecto_sql, "~> 3.9.0"},
      {:libvault, "~> 0.2.0"},
      {:ecto, "~> 3.9.0", override: true},
      {:postgrex, ">= 0.0.0"},
      {:ex_machina, "~> 2.7.0", only: :test},
      {:comeonin, "~> 5.3.0"},
      {:argon2_elixir, "~> 2.0"},
      {:piazza_core, "~> 0.3.8", git: "https://github.com/michaeljguarino/piazza_core"},
      {:inet_cidr, "~> 1.0.0"},
      {:dns, "~> 2.4.0"},
      {:bamboo, "~> 2.0"},
      {:parallax, "~> 1.0"},
      {:bourne, "~> 1.1"},
      {:flow, "~> 0.15.0"},
      {:joken, "~> 2.5.0"},
      {:guardian, "~> 1.2.1"},
      {:arc, "~> 0.11.0"},
      {:arc_gcs, "~> 0.2.0"},
      {:porcelain, "~> 2.0"},
      {:ex_aws, "~> 2.4.0"},
      {:ex_aws_s3, "~> 2.3.3"},
      {:ex_aws_sts, "~> 2.3.0"},
      {:posthog, "~> 0.1"},
      {:configparser_ex, "~> 4.0"},
      {:sweet_xml, "~> 0.7.3"},
      {:arc_ecto, "~> 0.11.3"},
      {:dictionary, "~> 0.1.0"},
      {:mojito, "~> 0.7.0"},
      {:nebulex, "== 2.4.2"},
      {:kazan, "~> 0.11", github: "michaeljguarino/kazan"},
      {:workos, "~> 0.1.2"},
      {:decorator, "~> 1.3"},   #=> For using Caching Annotations
      {:botanist, "~> 0.1.0", git: "https://github.com/michaeljguarino/botanist.git", branch: "ecto3"},
      {:x509, "~> 0.8.5"},
      {
        :briefly,
        git: "https://github.com/CargoSense/briefly",
        ref: "b0fd495bf0c5ef2c44de2791a8cc7a20813c7d36"
      },
      {:yaml_elixir, "~> 2.4"},
      {:timex, "~> 3.6"},
      {:oauth2, "~> 2.0"},
      {:websockex, "~> 0.4"},
      {:hackney, "~> 1.18.0", override: true},
      {:tzdata, "~> 1.1.0", override: true},
      {:prometheus_ex, "~> 3.0"},
      {:stripity_stripe, "~> 2.17.1"},
      {:conduit, "~> 0.12"},
      {:conduit_amqp, "~> 0.6.3"},
      {:rabbit_common, "~> 3.9", override: true},
      {:amqp, "~> 3.2", override: true},
      {:mime, "~> 1.2"},
      {:ex_image_info, "~> 0.2.4"},
      {:instream, "~> 1.0"},
      {:swarm, "~> 3.4.0"},
      {:poison, "~> 3.0"},
      {:cloudflare, "~> 0.2"},
      {:mint, "~> 1.0", override: true},
      {:mimic, "~> 1.1", only: :test},
      {:google_api_iam, "~> 0.40"},
      {:google_api_cloud_resource_manager, "~> 0.41"},
      {:google_api_cloud_billing, "~> 0.23"},
      {:google_api_service_usage, "~> 0.18"},
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
