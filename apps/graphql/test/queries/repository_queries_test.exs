defmodule GraphQl.RepositoryQueriesTest do
  use Core.SchemaCase, async: true
  import GraphQl.TestHelpers

  use Mimic

  describe "repositories" do
    test "It can list repositories for a publisher" do
      publisher = insert(:publisher)
      repos = insert_list(3, :repository, publisher: publisher)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query Repositories($publisherId: ID) {
          repositories(publisherId: $publisherId, first: 5) {
            edges { node { id } }
          }
        }
      """, %{"publisherId" => publisher.id}, %{current_user: insert(:user)})

      assert from_connection(found)
             |> ids_equal(repos)
    end

    test "it can sideload your installation state" do
      user = insert(:user)
      [first, second | _] = repos = insert_list(3, :repository)
      inst = insert(:installation, repository: first, user: user)
      insert(:installation, repository: second)
      insert(:installation, repository: first)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query {
          repositories(first: 5) {
            edges {
              node {
                id
                installation { id }
              }
            }
          }
        }
      """, %{}, %{current_user: user})

      list = from_connection(found)
      assert ids_equal(list, repos)

      {[repo], rest} = Enum.split_with(list, & &1["id"] == first.id)
      assert repo["installation"]["id"] == inst.id
      refute Enum.any?(rest, & &1["installation"])
    end

    test "It can sideload recipes for repositories" do
      publisher = insert(:publisher)
      repos = insert_list(3, :repository, publisher: publisher)
      recipes = Enum.into(repos, %{}, & {&1.id, insert_list(2, :recipe, repository: &1)})

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query Repositories($publisherId: ID) {
          repositories(publisherId: $publisherId, first: 5) {
            edges {
              node {
                id
                recipes { id }
              }
            }
          }
        }
      """, %{"publisherId" => publisher.id}, %{current_user: insert(:user)})

      assert from_connection(found)
             |> ids_equal(repos)

      assert from_connection(found)
             |> Enum.all?(&ids_equal(&1["recipes"], recipes[&1["id"]]))
    end

    test "It can respect private repositories" do
      account = insert(:account)
      publisher = insert(:publisher, account: account)
      repos = insert_list(3, :repository, publisher: publisher)
      private = insert(:repository, private: true, publisher: publisher)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query Repositories($publisherId: ID) {
          repositories(publisherId: $publisherId, first: 5) {
            edges { node { id } }
          }
        }
      """, %{"publisherId" => publisher.id}, %{current_user: insert(:user)})

      assert from_connection(found)
             |> ids_equal(repos)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query Repositories($publisherId: ID) {
          repositories(publisherId: $publisherId, first: 5) {
            edges { node { id } }
          }
        }
      """, %{"publisherId" => publisher.id}, %{current_user: insert(:user, account: account)})

      assert from_connection(found)
             |> ids_equal([private | repos])
    end

    test "It can list repositories installed by a user" do
      user = insert(:user)
      installations = insert_list(3, :installation, user: user)
      insert(:repository)

      {:ok, %{data: %{"repositories" => repos}}} = run_query("""
        query {
          repositories(installed: true, first: 5) {
            edges { node { id } }
          }
        }
      """, %{}, %{current_user: user})

      found_repos = from_connection(repos)
      assert Enum.map(installations, & &1.repository)
             |> ids_equal(found_repos)
    end

    test "It can list repositories not installed by a user" do
      user = insert(:user)
      insert_list(3, :installation, user: user)
      expected = insert(:repository)

      {:ok, %{data: %{"repositories" => repos}}} = run_query("""
        query {
          repositories(installed: false, first: 5) {
            edges { node { id } }
          }
        }
      """, %{}, %{current_user: user})

      assert from_connection(repos)
             |> ids_equal([expected])
    end

    test "It can list repositories for a tag" do
      user = insert(:user)
      repo  = insert(:repository, tags: [%{tag: "tag", resource_type: :repository}])
      other = insert(:repository, tags: [%{tag: "tag", resource_type: :repository}])
      insert(:repository)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query {
          repositories(first: 5, tag: "tag") {
            edges { node { id } }
          }
        }
      """, %{}, %{current_user: user})

      assert from_connection(found)
             |> ids_equal([repo, other])
    end

    test "it can list repositories you support" do
      account = insert(:account)
      user = insert(:user, account: account)

      publisher = insert(:publisher, account: account)
      role = insert(:role, repositories: ["repo"], permissions: %{support: true}, account: account)
      insert(:role_binding, role: role, user: user)
      role = insert(:role, repositories: ["other*"], permissions: %{support: true}, account: account)
      insert(:role_binding, role: role, user: user)

      repo1 = insert(:repository, publisher: publisher, name: "repo")
      repo2 = insert(:repository, publisher: publisher, name: "other-repo")
      insert(:repository, publisher: publisher)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query {
          repositories(first: 5, supports: true) {
            edges { node { id } }
          }
        }
      """, %{}, %{current_user: user})

      assert from_connection(found)
             |> ids_equal([repo1, repo2])
    end

    test "it can list all public repositories" do
      repos = insert_list(3, :repository)
      insert(:repository, private: true)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query {
          repositories(first: 5) {
            edges { node { id } }
          }
        }
      """, %{})

      assert from_connection(found)
             |> ids_equal(repos)
    end

    test "it can list all repositories for a provider" do
      repos = insert_list(3, :repository)
      for r <- repos,
        do: insert(:recipe, repository: r, provider: :aws)
      insert(:recipe, provider: :gcp)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query {
          repositories(first: 5, provider: AWS) {
            edges { node { id } }
          }
        }
      """, %{})

      assert from_connection(found)
             |> ids_equal(repos)
    end

    test "it can search all public repositories" do
      repos = for i <- 1..3, do: insert(:repository, name: "query #{i}")
      insert(:repository)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query Search($q: String!) {
          repositories(q: $q, first: 5) {
            edges { node { id } }
          }
        }
      """, %{"q" => "query"})

      assert from_connection(found)
             |> ids_equal(repos)
    end

    test "it will filter by category" do
      repos = insert_list(3, :repository, category: :data)
      insert(:repository, category: :security)

      {:ok, %{data: %{"repositories" => found}}} = run_query("""
        query Search($cat: Category!) {
          repositories(category: $cat, first: 5) {
            edges { node { id } }
          }
        }
      """, %{"cat" => "DATA"})

      assert from_connection(found)
             |> ids_equal(repos)
    end
  end

  describe "repository" do
    test "It can fetch a repository by id" do
      user = insert(:user)
      repo = insert(:repository, publisher: build(:publisher, owner: user))

      {:ok, %{data: %{"repository" => found}}} = run_query("""
        query Repo($repoId: ID!) {
          repository(id: $repoId) {
            id
            editable
          }
        }
      """, %{"repoId" => repo.id}, %{current_user: user})

      assert found["id"] == repo.id
      assert found["editable"]
    end

    test "It can fetch repository documentation" do
      user = insert(:user)
      repo = insert(:repository, publisher: build(:publisher, owner: user), docs: %{file_name: "f", updated_at: nil})

      contents = priv_file(:core, "docs.tgz") |> File.read!()
      expect(HTTPoison, :get, fn _, _, _ -> {:ok, %HTTPoison.Response{status_code: 200, body: contents}} end)

      {:ok, %{data: %{"repository" => found}}} = run_query("""
        query Repo($repoId: ID!) {
          repository(id: $repoId) {
            id
            docs { path content }
          }
        }
      """, %{"repoId" => repo.id}, %{current_user: user})

      assert found["id"] == repo.id
      by_name = Enum.into(found["docs"], %{}, & {&1["path"], &1["content"]})

      assert by_name["test.md"] == "hello world"
      assert by_name["other.md"] == "another file"
    end

    test "It will respect privacy" do
      user = insert(:user)
      account = insert(:account)
      repo = insert(:repository, private: true, publisher: build(:publisher, account: account))

      {:ok, %{data: %{"repository" => nil}}} = run_query("""
        query Repo($repoId: ID!) {
          repository(id: $repoId) {
            id
            editable
          }
        }
      """, %{"repoId" => repo.id}, %{current_user: user})

      {:ok, %{data: %{"repository" => found}}} = run_query("""
        query Repo($repoId: ID!) {
          repository(id: $repoId) {
            id
            editable
          }
        }
      """, %{"repoId" => repo.id}, %{current_user: insert(:user, account: account)})

      assert found["id"] == repo.id
    end

    test "it can fetch a repository by name" do
      user = insert(:user)
      repo = insert(:repository)

      {:ok, %{data: %{"repository" => found}}} = run_query("""
        query Repo($name: String!) {
          repository(name: $name) {
            id
            editable
          }
        }
      """, %{"name" => repo.name}, %{current_user: user})

      assert found["id"] == repo.id
    end

    test "It can sideload installations and upgradeChannels" do
      %{repository: repo, user: user} = insert(:installation)
      insert(:version_tag, tag: "one", chart: build(:chart, repository: repo))
      insert(:version_tag, tag: "two", terraform: build(:terraform, repository: repo))
      insert(:version_tag, tag: "one", terraform: build(:terraform, repository: repo))
      insert(:version_tag, tag: "three", chart: build(:chart, repository: repo))

      {:ok, %{data: %{"repository" => found}}} = run_query("""
        query Repo($repoId: ID!) {
          repository(id: $repoId) {
            id
            installation {
              user { id }
            }
            upgradeChannels
            editable
          }
        }
      """, %{"repoId" => repo.id}, %{current_user: user})

      assert found["id"] == repo.id
      assert found["installation"]["user"]["id"] == user.id
      assert MapSet.new(found["upgradeChannels"]) |> MapSet.equal?(MapSet.new(~w(one two three)))
      refute found["editable"]
    end

    test "publishers can see their public keys" do
      %{owner: user} = insert(:publisher)
      {:ok, repo} = Core.Services.Repositories.create_repository(%{name: "my-repo", category: :data}, user)

      {:ok, %{data: %{"repository" => found}}} = run_query("""
        query Repo($id: ID!) {
          repository(id: $id) {
            id
            publicKey
          }
        }
      """, %{"id" => repo.id}, %{current_user: user})

      assert found["id"] == repo.id
      assert found["publicKey"] == repo.public_key
    end

    test "nonpublishers cannot see public keys" do
      %{owner: user} = insert(:publisher)
      {:ok, repo} = Core.Services.Repositories.create_repository(%{name: "my-repo", category: :data}, user)

      {:ok, %{data: %{"repository" => found}}} = run_query("""
        query Repo($id: ID!) {
          repository(id: $id) {
            id
            publicKey
          }
        }
      """, %{"id" => repo.id}, %{current_user: insert(:user)})

      assert found["id"] == repo.id
      refute found["publicKey"]
    end
  end

  describe "installation" do
    test "it can fetch a repository installation by name" do
      repo = insert(:repository)
      inst = insert(:installation, repository: repo)

      {:ok, %{data: %{"installation" => found}}} = run_query("""
        query Installation($name: String!) {
          installation(name: $name) { id }
        }
      """, %{"name" => repo.name}, %{current_user: inst.user})

      assert found["id"] == inst.id
    end
  end

  describe "searchRepositories" do
    test "It can search for substrings of a repo name" do
      repos = for i <- 1..3, do: insert(:repository, name: "query #{i}")
      insert(:repository)

      {:ok, %{data: %{"searchRepositories" => found}}} = run_query("""
        query SearchRepositories($query: String!) {
          searchRepositories(query: $query, first: 5) {
            edges { node { id } }
          }
        }
      """, %{"query" => "query"}, %{current_user: insert(:user)})

      assert from_connection(found)
             |> ids_equal(repos)
    end
  end

  describe "integrations" do
    test "It will list integrations" do
      repository = insert(:repository)
      integrations = insert_list(3, :integration, repository: repository)

      {:ok, %{data: %{"integrations" => found}}} = run_query("""
        query Integrations($name: String) {
          integrations(repositoryName: $name, first: 5) {
            edges { node { id } }
          }
        }
      """, %{"name" => repository.name}, %{current_user: insert(:user)})

      assert from_connection(found)
             |> ids_equal(integrations)
    end

    test "It will list integrations for a tag" do
      repository = insert(:repository)
      first  = insert(:integration, repository: repository, tags: [%{tag: "tag", resource_type: :integration}])
      second = insert(:integration, repository: repository, tags: [%{tag: "tag", resource_type: :integration}])
      insert(:integration, repository: repository)

      {:ok, %{data: %{"integrations" => found}}} = run_query("""
        query Integrations($name: String!, $tag: String!) {
          integrations(repositoryName: $name, tag: $tag, first: 5) {
            edges { node { id } }
          }
        }
      """, %{"name" => repository.name, "tag" => "tag"}, %{current_user: insert(:user)})

      assert from_connection(found)
             |> ids_equal([first, second])
    end

    test "it will list integrations for a type" do
      repository = insert(:repository)
      first  = insert(:integration, repository: repository, type: "something")
      second = insert(:integration, repository: repository, type: "something")
      insert(:integration, repository: repository)

      {:ok, %{data: %{"integrations" => found}}} = run_query("""
        query Integrations($name: String!, $type: String!) {
          integrations(repositoryName: $name, type: $type, first: 5) {
            edges { node { id } }
          }
        }
      """, %{"name" => repository.name, "type" => "something"}, %{})

      assert from_connection(found)
             |> ids_equal([first, second])
    end
  end

  describe "categories" do
    test "it will render categories and repo counts" do
      insert_list(2, :repository, category: :devops)
      insert(:repository, category: :database)

      {:ok, %{data: %{"categories" => cats}}} = run_query("""
        query {
          categories { category count }
        }
      """, %{}, %{current_user: insert(:user)})

      by_category = Enum.into(cats, %{}, & {&1["category"], &1})

      assert by_category["DEVOPS"]["count"] == 2
      assert by_category["DATABASE"]["count"] == 1
    end
  end

  describe "category" do
    test "it can paginate tags for a category" do
      insert(:repository, category: :devops, tags: [%{tag: "tag", resource_type: :repository}])
      insert(:repository, category: :devops, tags: [%{tag: "other", resource_type: :repository}])
      insert(:repository, category: :devops, tags: [%{tag: "other", resource_type: :repository}])

      {:ok, %{data: %{"category" => category}}} = run_query("""
        query Cat($category: Category!) {
          category(name: $category) {
            category
            tags(first: 5) {
              edges { node { tag count } }
            }
          }
        }
      """, %{"category" => "DEVOPS"}, %{current_user: insert(:user)})

      assert category["category"] == "DEVOPS"
      [first, second] = from_connection(category["tags"])
      assert first["tag"] == "other"
      assert first["count"] == 2

      assert second["tag"] == "tag"
      assert second["count"] == 1
    end
  end

  describe "scaffold" do
    test "it won't explode" do
      {:ok, %{data: %{"scaffold" => _}}} = run_query("""
        query Scaffold($app: String!, $pub: String!, $cat: Category!) {
          scaffold(application: $app, category: $cat, publisher: $pub) { path content }
        }
      """, %{"app" => "app", "pub" => "Pub", "cat" => "DATA"})
    end
  end
end
