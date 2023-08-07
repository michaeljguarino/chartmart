defmodule Core.Services.ChartsTest do
  use Core.SchemaCase, async: true
  use Mimic
  alias Core.Services.Charts

  describe "#list_charts_and_versions/1" do
    test "it can list charts and their versions for the repo" do
      repo = insert(:repository)
      [first, second] = insert_list(2, :chart, repository: repo)
      insert(:chart)
      first_v = insert(:version, chart: first)
      second_v = insert(:version, chart: second)

      results = Charts.list_charts_and_versions(repo.id)
      assert ids_equal([first, second], results)

      by_id = Enum.into(results, %{}, & {&1.id, &1})
      assert hd(by_id[first.id].versions).id == first_v.id
      assert hd(by_id[second.id].versions).id == second_v.id
    end
  end

  describe "#create_chart" do
    test "A user can create a chart if he's a publisher" do
      user = insert(:user)
      pub  = insert(:publisher, owner: user)
      repo = insert(:repository, publisher: pub)

      {:ok, chart} = Charts.create_chart(%{name: "somechart", latest_version: "0.1.0"}, repo.id, user)

      assert chart.name == "somechart"
      assert chart.repository_id == repo.id
      assert chart.latest_version == "0.1.0"

      assert Charts.get_chart_version(chart.id, "0.1.0")
      assert Charts.get_tag(chart.id, "latest")
    end
  end

  describe "#update_chart" do
    test "It can add tags" do
      user  = insert(:user)
      pub   = insert(:publisher, owner: user)
      repo  = insert(:repository, publisher: pub)
      chart = insert(:chart, repository: repo)
      version = insert(:version, chart: chart, version: "1.1.0")

      {:ok, %{tags: [tag]}} = Charts.update_chart(%{tags: [%{version_id: version.id, tag: "stable"}]}, chart.id, user)

      assert tag.tag == "stable"
      assert tag.chart_id == chart.id
      assert tag.version_id == version.id
    end
  end

  describe "#create_chart_installation" do
    test "A user can install valid versions of a chart" do
      %{chart: chart, id: vid} = insert(:version, version: "1.0.0")
      user = insert(:user)
      installation = insert(:installation, repository: chart.repository, user: user)

      {:ok, ci} = Charts.create_chart_installation(%{
        version_id: vid,
        chart_id: chart.id
      }, installation.id, user)

      assert ci.version_id == vid
      assert ci.chart_id == chart.id
      assert ci.installation_id == installation.id
    end

    test "If there is no installation of the chart's repo, it can't be installed" do
      %{chart: chart} = version = insert(:version, version: "1.0.0")
      user = insert(:user)
      installation = insert(:installation, user: user)

      {:error, _} = Charts.create_chart_installation(%{
        version_id: version.id,
        chart_id: chart.id
      }, installation.id, user)
    end

    test "If the version is invalid, it can't be installed" do
      %{chart: chart} = insert(:version, version: "1.0.0")
      user = insert(:user)
      installation = insert(:installation, repository: chart.repository, user: user)
      version = insert(:version)

      {:error, _} = Charts.create_chart_installation(%{
        version_id: version.id,
        chart_id: chart.id
      }, installation.id, user)
    end

    test "If dependencies are met it can install" do
      chart = insert(:chart)
      tf    = insert(:terraform)
      user  = insert(:user)
      insert(:chart_installation,
        chart: chart,
        installation: insert(:installation, user: user, repository: chart.repository)
      )
      insert(:terraform_installation,
        terraform: tf,
        installation: insert(:installation, user: user, repository: tf.repository)
      )

      %{chart: chart, id: vid} = insert(:version, version: "1.0.0", dependencies: %{dependencies: [
        %{type: :helm, repo: chart.repository.name, name: chart.name},
        %{type: :terraform, repo: tf.repository.name, name: tf.name}
      ]})
      installation = insert(:installation, repository: chart.repository, user: user)

      {:ok, _} = Charts.create_chart_installation(%{
        version_id: vid,
        chart_id: chart.id
      }, installation.id, user)
    end

    test "If dependencies aren't met it can't install" do
      chart = insert(:chart)
      tf    = insert(:terraform)
      user  = insert(:user)
      insert(:terraform_installation,
        terraform: tf,
        installation: insert(:installation, user: user, repository: tf.repository)
      )

      %{chart: chart, id: vid} = insert(:version, version: "1.0.0", dependencies: %{dependencies: [
        %{type: :helm, repo: chart.repository.name, name: chart.name},
        %{type: :terraform, repo: tf.repository.name, name: tf.name}
      ]})
      installation = insert(:installation, repository: chart.repository, user: user)

      {:error, _} = Charts.create_chart_installation(%{
        version_id: vid,
        chart_id: chart.id
      }, installation.id, user)
    end
  end

  describe "#install_chart_version/4" do
    test "it can install a chart installation by names" do
      %{chart: chart} = v = insert(:version, version: "1.0.0")
      user = insert(:user)
      installation = insert(:installation, repository: chart.repository, user: user)
      chart_inst = insert(:chart_installation, installation: installation, chart: chart, version: v)
      v2 = insert(:version, chart: chart, version: "2.0")

      {:ok, ci} = Charts.install_chart_version("2.0", chart.name, chart.repository.name, user)

      assert ci.id == chart_inst.id
      assert ci.version_id == v2.id
    end
  end

  describe "#update_chart_installation" do
    test "A user can update his chart installation" do
      %{chart: chart} = v = insert(:version, version: "1.0.0")
      user = insert(:user)
      installation = insert(:installation, repository: chart.repository, user: user)
      chart_inst = insert(:chart_installation, installation: installation, chart: chart, version: v)
      v2 = insert(:version, chart: chart, version: "2.0")

      {:ok, ci} = Charts.update_chart_installation(%{
        version_id: v2.id
      }, chart_inst.id, user)

      assert ci.id == chart_inst.id
      assert ci.version_id == v2.id
    end
  end

  describe "#delete_chart_installation" do
    test "A user can delete his chart installation" do
      %{chart: chart} = v = insert(:version, version: "1.0.0")
      user = insert(:user)
      installation = insert(:installation, repository: chart.repository, user: user)
      chart_inst = insert(:chart_installation, installation: installation, chart: chart, version: v)

      {:ok, _} = Charts.delete_chart_installation( chart_inst.id, user)

      refute refetch(chart_inst)
    end

    test "A user cannot delete other chart installations" do
      %{chart: chart} = v = insert(:version, version: "1.0.0")
      user = insert(:user)
      installation = insert(:installation, repository: chart.repository)
      chart_inst = insert(:chart_installation, installation: installation, chart: chart, version: v)

      {:error, _} = Charts.delete_chart_installation( chart_inst.id, user)
    end
  end

  describe "#sync_version" do
    test "It will add helm info onto a chart version" do
      version = insert(:version)

      {:ok, version} = Charts.sync_version(
        %{helm: %{"description" => "some chart"}},
        version.chart_id,
        version.version
      )

      assert version.helm == %{"description" => "some chart"}
    end
  end

  describe "#extract_chart_meta/2" do
    test "It can extract info from a tar file" do
      path = Path.join(:code.priv_dir(:core), "azure-identity-0.1.1.tgz")
      {:ok, %{readme: _, helm: _, values_template: template, dependencies: deps, template_type: t}} = Charts.extract_chart_meta("azure-identity", path)

      assert is_binary(template)
      assert t == :gotemplate
      assert deps["dependencies"]
    end
  end

  describe "#chart_info/2" do
    test "it can extract chart name and version from the filename" do
      {name, version} = Charts.chart_info(%{filename: "azure-identity-0.1.1.tgz"})

      assert name == "azure-identity"
      assert version == "0.1.1"
    end
  end

  describe "#upload_chart/4" do
    @tag :skip
    test "It can upload a chart" do
      path = Path.join(:code.priv_dir(:core), "console-0.5.24.tgz")
      repo = insert(:repository, name: "console")
      registry = insert(:docker_repository, repository: repo, name: "console")
      img = insert(:docker_image, docker_repository: registry, tag: "0.1.0")

      expect(HTTPoison, :post, fn _, _, _, _ -> {:ok, %{}} end)
      {:ok, %{sync_chart: chart, imgs: [img_dep], sync: sync}} = Charts.upload_chart(
        %{"chart" => %{filename: path, path: path}},
        repo,
        repo.publisher.owner,
        %{opts: [], headers: []}
      )

      assert length(chart.dependencies.dependencies) == 4
      assert img_dep.image_id == img.id
      assert img_dep.version_id == sync.id
    end
  end

  describe "#create_crd/3" do
    test "A publisher can create crds for a repository" do
      %{owner: user} = pub = insert(:publisher)
      repo = insert(:repository, publisher: pub)
      version = insert(:version, chart: build(:chart, repository: repo))

      {:ok, crd} = Charts.create_crd(%{name: "example.yaml"}, version.id, user)

      assert crd.name == "example.yaml"
    end

    test "A random user cannot create crds for a repository" do
      user = insert(:user)
      version = insert(:version)

      {:error, _} = Charts.create_crd(%{name: "example.yaml"}, version.id, user)
    end
  end

  describe "#get_crds" do
    test "it will find the contents of the crd folder" do
      chart_contents = Enum.map([
        {"Chart.yaml", "chart: value"},
        {"templates/deployment.yaml", "example"},
        {"crds/mycrd.yaml", "a crd"}
      ], fn {name, val} -> {String.to_charlist("chart/#{name}"), val} end)

      [{name, val}] = Charts.get_crds(chart_contents, "chart/crds/")

      assert name == "chart/crds/mycrd.yaml"
      assert val == "a crd"
    end
  end
end
