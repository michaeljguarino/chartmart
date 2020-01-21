defmodule GraphQl.UserMutationTest do
  use Core.SchemaCase, async: true
  import GraphQl.TestHelpers
  alias Core.Services.Users
  use Mimic

  describe "login" do
    test "A user can log in with a password" do
      {:ok, user} = Users.create_user(%{
        name: "Michael Guarino",
        email: "mguarino46@gmail.com",
        password: "super strong password"
      })

      {:ok, %{data: %{"login" => found}}} = run_query("""
        mutation Login($email: String!, $password: String!) {
          login(email: $email, password: $password) {
            id
            jwt
          }
        }
      """, %{"email" => "mguarino46@gmail.com", "password" => "super strong password"})

      assert found["id"] == user.id
      assert found["jwt"]
    end

    test "Incorrect passwords fail" do
      {:ok, _} = Users.create_user(%{
        name: "Michael Guarino",
        email: "mguarino46@gmail.com",
        password: "super strong password"
      })

      {:ok, %{errors: [_ | _]}} = run_query("""
        mutation Login($email: String!, $password: String!) {
          login(email: $email, password: $password) {
            id
          }
        }
      """, %{"email" => "mguarino46@gmail.com", "password" => "incorrect password"})
    end
  end

  describe "signup" do
    test "it can create a new user" do
      {:ok, %{data: %{"signup" => signup}}} = run_query("""
        mutation Signup($attributes: UserAttributes!) {
          signup(attributes: $attributes) {
            id
            name
            email
            jwt
          }
        }
      """, %{"attributes" => %{
        "email" => "mguarino46@gmail.com",
        "password" => "super strong password",
        "name" => "Michael Guarino"
      }})

      assert signup["id"]
      assert signup["name"] == "Michael Guarino"
      assert signup["email"] == "mguarino46@gmail.com"
      assert signup["jwt"]
    end
  end

  describe "updateUser" do
    test "Users can update themselves" do
      {:ok, user} = Users.create_user(%{
        name: "Michael Guarino",
        email: "mguarino46@gmail.com",
        password: "super strong password"
      })

      {:ok, %{data: %{"updateUser" => updated}}} = run_query("""
        mutation UpdateUser($name: String) {
          updateUser(attributes: {name: $name}) {
            id
            name
          }
        }
      """, %{"name" => "Updated User"}, %{current_user: user})

      assert updated["id"] == user.id
      assert updated["name"] == "Updated User"
    end
  end

  describe "createPublisher" do
    test "A user can create a publisher" do
      user = insert(:user)

      {:ok, %{data: %{"createPublisher" => publisher}}} = run_query("""
        mutation CreatePublisher($attrs: PublisherAttributes!) {
          createPublisher(attributes: $attrs) {
            id
            name
            owner {
              id
            }
          }
        }
      """, %{"attrs" => %{"name" => "my publisher"}}, %{current_user: user})

      assert publisher["id"]
      assert publisher["name"] == "my publisher"
      assert publisher["owner"]["id"] == user.id
    end
  end

  describe "updatePublisher" do
    test "A user can update their publisher" do
      %{owner: user} = pub = insert(:publisher)

      {:ok, %{data: %{"updatePublisher" => update}}} = run_query("""
        mutation UpdatePublisher($name: String) {
          updatePublisher(attributes: {name: $name}) {
            id
            name
          }
        }
      """, %{"name" => "updated publisher"}, %{current_user: user})

      assert update["id"] == pub.id
      assert update["name"] == "updated publisher"
    end
  end

  describe "createToken" do
    test "A user can create a token for themself" do
      user = insert(:user)

      {:ok, %{data: %{"createToken" => token}}} = run_query("""
        mutation {
          createToken {
            id
            token
          }
        }
      """, %{}, %{current_user: user})

      assert token["id"]
      assert token["token"]
    end
  end

  describe "deleteToken" do
    test "A user can delete a persisted token" do
      user = insert(:user)
      token = insert(:persisted_token, user: user)

      {:ok, %{data: %{"deleteToken" => deleted}}} = run_query("""
        mutation DeleteToken($id: ID!) {
          deleteToken(id: $id) {
            id
          }
        }
      """, %{"id" => token.id}, %{current_user: user})

      assert deleted["id"] == token.id
    end
  end

  describe "createWebhook" do
    test "A user can create a webhook" do
      user = insert(:user)

      {:ok, %{data: %{"createWebhook" => created}}} = run_query("""
        mutation createWebhook($url: String!) {
          createWebhook(attributes: {url: $url}) {
            id
            url
          }
        }
      """, %{"url" => "https://example.com"}, %{current_user: user})

      assert created["url"] == "https://example.com"
    end
  end

  describe "pingWebhook" do
    test "It will send a POST to the given webhook" do
      user = insert(:user)
      webhook = insert(:webhook, user: user)

      expect(Mojito, :post, fn _, _, payload -> {:ok, %Mojito.Response{status_code: 200, body: payload}} end)

      {:ok, %{data: %{"pingWebhook" => response}}} = run_query("""
        mutation pingWebhook($repo: String!, $id: ID!) {
          pingWebhook(repo: $repo, id: $id) {
            statusCode
            body
          }
        }
      """, %{"repo" => "repo", "id" => webhook.id}, %{current_user: user})
      assert response["body"] == Jason.encode!(%{repo: "repo"})
      assert response["statusCode"] == 200
    end
  end
end