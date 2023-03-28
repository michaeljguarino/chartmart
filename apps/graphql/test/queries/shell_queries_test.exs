defmodule GraphQl.ShellQueriesTest do
  use Core.SchemaCase, async: true
  import GraphQl.TestHelpers
  use Mimic
  alias Core.Services.Shell.Pods
  alias Core.Shell.{Models, Client}
  alias GoogleApi.CloudResourceManager.V3

  describe "shell" do
    test "it can fetch a cloud shell instance including its liveness" do
      pod = Pods.pod("plrl-shell-1", "mjg@plural.sh")
      expect(Pods, :fetch, fn "plrl-shell-1" -> {:ok, pod} end)

      shell = insert(:cloud_shell, pod_name: "plrl-shell-1", workspace: %{cluster: "cluster", region: "us-east2"})

      {:ok, %{data: %{"shell" => found}}} = run_query("""
        query {
          shell { id alive cluster region }
        }
      """, %{}, %{current_user: shell.user})

      assert found["id"] == shell.id
      assert found["cluster"] == "cluster"
      assert found["region"] == "us-east2"
      refute found["alive"]
    end
  end

  describe "scmAuthorization" do
    test "it can list authz urls for scm providers" do
      user = insert(:user)

      {:ok, %{data: %{"scmAuthorization" => [github, gitlab]}}} = run_query("""
        query {
          scmAuthorization { provider url }
        }
      """, %{}, %{current_user: user})

      assert github["provider"] == "GITHUB"
      assert github["url"]

      assert gitlab["provider"] == "GITLAB"
      assert gitlab["url"]
    end
  end

  describe "scmToken" do
    test "it can fetch an access token for an scm provider" do
      user = insert(:user)

      expect(Core.Shell.Scm, :get_token, fn :github, "code" -> {:ok, "access"} end)

      {:ok, %{data: %{"scmToken" => tok}}} = run_query("""
        query Token($code: String!, $prov: ScmProvider!) {
          scmToken(code: $code, provider: $prov)
        }
      """, %{"code" => "code", "prov" => "GITHUB"}, %{current_user: user})

      assert tok == "access"
    end
  end

  describe "shellConfiguration" do
    test "it can fetch the configuration from your cloud shell" do
      expect(Pods, :ip, fn "plrl-shell-1" -> {:ok, "0.0.0.0"} end)

      shell = insert(:cloud_shell, pod_name: "plrl-shell-1", workspace: %{cluster: "cluster"})

      expect(HTTPoison, :request, fn :get, "http://0.0.0.0:8080/v1/configuration", _, _, _ ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Poison.encode!(%Models.Configuration{
          workspace: %Models.Workspace{bucket_prefix: "pre", network: %Models.Network{plural_dns: true}},
          git: %Models.Git{url: "git"},
          context_configuration: %{"some" => "config"},
          buckets: ["bucket"],
          domains: ["some.example.com"]
        })}}
      end)

      {:ok, %{data: %{"shellConfiguration" => found}}} = run_query("""
        query {
          shellConfiguration {
            workspace { bucketPrefix network { pluralDns } }
            git { url }
            contextConfiguration
            buckets
            domains
          }
        }
      """, %{}, %{current_user: shell.user})

      assert found["workspace"]["bucketPrefix"] == "pre"
      assert found["workspace"]["network"]["pluralDns"]
      assert found["git"]["url"] == "git"
      assert found["contextConfiguration"] == %{"some" => "config"}
      assert found["buckets"] == ["bucket"]
      assert found["domains"] == ["some.example.com"]
    end
  end

  describe "shellApplications" do
    test "it can fetch the applications from your cloud shell" do
      expect(Pods, :ip, fn "plrl-shell-1" -> {:ok, "0.0.0.0"} end)

      shell = insert(:cloud_shell, pod_name: "plrl-shell-1", workspace: %{cluster: "cluster"})

      expect(HTTPoison, :request, fn :get, "http://0.0.0.0:8080/v1/applications", _, _, _ ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Poison.encode!([
          %Client.Application{
            metadata: %Client.Application.Metadata{name: "airbyte"},
            spec: %Client.ApplicationSpec{
              descriptor: %Client.ApplicationSpec.Descriptor{
                links: [%Client.ApplicationSpec.Link{url: "airbyte.plural.sh"}]
              }
            },
            status: %Client.ApplicationStatus{
              components: [%Client.ApplicationStatus.Component{group: "v1", kind: "deployment", name: "airbyte", status: "Ready"}],
              conditions: [%Client.ApplicationStatus.Condition{type: "Ready", status: "True"}],
            }
          }
        ])}}
      end)

      {:ok, %{data: %{"shellApplications" => [found]}}} = run_query("""
        query {
          shellApplications {
            name
            ready
            components { kind name status }
            spec { links { url } }
          }
        }
      """, %{}, %{current_user: shell.user})

      assert found["ready"]
      assert found["name"] == "airbyte"
      assert found["components"] == [%{"kind" => "deployment", "status" => "Ready", "name" => "airbyte"}]
      assert found["spec"]["links"] == [%{"url" => "airbyte.plural.sh"}]
    end
  end

  describe "demoProject" do
    test "it will poll a demo project for the given id" do
      demo = insert(:demo_project)

      expect(Goth.Token, :for_scope, fn _ -> {:ok, %{token: "token"}} end)
      expect(V3.Api.Operations, :cloudresourcemanager_operations_get, fn _, _ ->
        {:ok, %V3.Model.Operation{done: false}}
      end)

      {:ok, %{data: %{"demoProject" => found}}} = run_query("""
        query Demo($id: ID!) {
          demoProject(id: $id) { id }
        }
      """, %{"id" => demo.id}, %{current_user: demo.user})

      assert found["id"] == demo.id
    end

    test "it will poll a demo project for the current user" do
      demo = insert(:demo_project)

      expect(Goth.Token, :for_scope, fn _ -> {:ok, %{token: "token"}} end)
      expect(V3.Api.Operations, :cloudresourcemanager_operations_get, fn _, _ ->
        {:ok, %V3.Model.Operation{done: false}}
      end)

      {:ok, %{data: %{"demoProject" => found}}} = run_query("""
        query Demo($id: ID) {
          demoProject(id: $id) { id }
        }
      """, %{"id" => nil}, %{current_user: demo.user})

      assert found["id"] == demo.id
    end

    test "it will return not found when polling a non-existing demo project for the user" do
      user = insert(:user)

      {:ok, %{data: %{"demoProject" => _}, errors: [%{code: code, locations: _, message: message, path: _}]}} = run_query("""
        query Demo($id: ID) {
          demoProject(id: $id) { id }
        }
      """, %{"id" => nil}, %{current_user: user})

      assert code == 404
      assert message == "Demo project not found"
    end
  end
end
