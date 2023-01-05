defmodule GraphQl.AccountMutationTest do
  use Core.SchemaCase, async: true
  use Mimic
  import GraphQl.TestHelpers

  describe "createServiceAccount" do
    setup [:setup_root_user]

    test "it can create service accounts", %{user: user, account: account} do
      insert(:platform_subscription, account: account, plan: build(:platform_plan, features: %{user_management: true}))
      group = insert(:group, account: user.account)
      {:ok, %{data: %{"createServiceAccount" => svc}}} = run_query("""
        mutation createSvcAccount($attributes: ServiceAccountAttributes!) {
          createServiceAccount(attributes: $attributes) {
            id
            serviceAccount
            impersonationPolicy {
              bindings { group { id } }
            }
          }
        }
      """,
      %{
        "attributes" => %{
          "name" => "svc",
          "impersonationPolicy" => %{"bindings" => [%{"groupId" => group.id}]}
        }
      },
      %{current_user: Core.Services.Rbac.preload(user)})

      assert svc["serviceAccount"]
      assert hd(svc["impersonationPolicy"]["bindings"])["group"]["id"] == group.id
    end

    test "delinquent accounts cannot create service accounts", %{user: user, account: account} do
      {:ok, account} = update_record(account, %{delinquent_at: Timex.now() |> Timex.shift(days: -100)})
      insert(:platform_subscription, account: account, plan: build(:platform_plan, features: %{user_management: true}))
      group = insert(:group, account: user.account)
      {:ok, %{errors: [_ | _]}} = run_query("""
        mutation createSvcAccount($attributes: ServiceAccountAttributes!) {
          createServiceAccount(attributes: $attributes) {
            id
            serviceAccount
            impersonationPolicy {
              bindings { group { id } }
            }
          }
        }
      """,
      %{
        "attributes" => %{
          "name" => "svc",
          "impersonationPolicy" => %{"bindings" => [%{"groupId" => group.id}]}
        }
      },
      %{current_user: Core.Services.Rbac.preload(refetch(user))})
    end

    test "it will fail to create service accounts if feature doesn't exist", %{user: user} do
      group = insert(:group, account: user.account)
      {:ok, %{errors: [_ | _]}} = run_query("""
        mutation createSvcAccount($attributes: ServiceAccountAttributes!) {
          createServiceAccount(attributes: $attributes) {
            id
            serviceAccount
            impersonationPolicy {
              bindings { group { id } }
            }
          }
        }
      """,
      %{
        "attributes" => %{
          "name" => "svc",
          "impersonationPolicy" => %{"bindings" => [%{"groupId" => group.id}]}
        }
      },
      %{current_user: Core.Services.Rbac.preload(user)})
    end
  end

  describe "updateServiceAccount" do
    setup [:setup_root_user]

    test "it can create service accounts", %{user: user} do
      svc_account = insert(:user, service_account: true, account: user.account)
      group = insert(:group, account: user.account)

      {:ok, %{data: %{"updateServiceAccount" => svc}}} = run_query("""
        mutation updateSvcAccount($id: ID!, $attributes: ServiceAccountAttributes!) {
          updateServiceAccount(id: $id, attributes: $attributes) {
            id
            serviceAccount
            impersonationPolicy {
              bindings { group { id } }
            }
          }
        }
      """,
      %{
        "id" => svc_account.id,
        "attributes" => %{
          "name" => "svc",
          "impersonationPolicy" => %{"bindings" => [%{"groupId" => group.id}]}
        }
      },
      %{current_user: user})

      assert svc["id"] == svc_account.id
      assert svc["serviceAccount"]
      assert hd(svc["impersonationPolicy"]["bindings"])["group"]["id"] == group.id
    end
  end

  describe "impersonateServiceAccount" do
    test "a user can impersonate a service account" do
      user = insert(:user)
      sa = insert(:user, service_account: true, account: user.account)
      %{group: group} = insert(:impersonation_policy_binding,
        policy: build(:impersonation_policy, user: sa),
        group: insert(:group, account: user.account)
      )
      insert(:group_member, group: group, user: user)

      {:ok, %{data: %{"impersonateServiceAccount" => imp}}} = run_query("""
        mutation Impersonate($email: String) {
          impersonateServiceAccount(email: $email) {
            id
            jwt
          }
        }
      """, %{"email" => sa.email}, %{current_user: user})

      assert imp["id"] == sa.id
      assert imp["jwt"]
    end
  end

  describe "updateAccount" do
    setup [:setup_root_user]

    test "it can update accounts", %{user: user} do
      {:ok, %{data: %{"updateAccount" => account}}} = run_query("""
        mutation updateAccount($attrs: AccountAttributes!) {
          updateAccount(attributes: $attrs) {
            name
            domainMappings { domain }
          }
        }
      """, %{"attrs" => %{
        "name" => "updated",
        "domainMappings" => [%{"domain" => "example.com"}]
      }}, %{current_user: user})

      assert account["name"] == "updated"
      assert account["domainMappings"] == [%{"domain" => "example.com"}]
    end
  end

  describe "createInvite" do
    setup [:setup_root_user]

    test "creates an invite", %{user: user} do
      {:ok, %{data: %{"createInvite" => create}}} = run_query("""
        mutation Create($attributes: InviteAttributes!) {
          createInvite(attributes: $attributes) {
            email
          }
        }
      """, %{"attributes" => %{"email" => "some@email.com"}}, %{current_user: user})


      assert create["email"] == "some@email.com"
    end
  end

  describe "deleteInvite" do
    setup [:setup_root_user]

    test "deletes an invite", %{user: user, account: account} do
      invite = insert(:invite, account: account, secure_id: "a-id")
      {:ok, %{data: %{"deleteInvite" => del}}} = run_query("""
        mutation Delete($id: String!) {
          deleteInvite(secureId: $id) {
            secureId
          }
        }
      """, %{"id" => "a-id"}, %{current_user: user})

      assert del["secureId"] == invite.secure_id
      refute refetch(invite)
    end
  end

  describe "realizeInvite" do
    test "it can realize an invite" do
      user = insert(:user)
      invite = insert(:invite, user: user, email: user.email)

      {:ok, %{data: %{"realizeInvite" => _}}} = run_query("""
        mutation Realize($id: String!) {
          realizeInvite(id: $id) {
            id
          }
        }
      """, %{"id" => invite.secure_id})

      assert refetch(user).account_id == invite.account_id
    end
  end

  describe "createGroup" do
    setup [:setup_root_user]

    test "creates a group if feature is enabled", %{user: user, account: account} do
      insert(:platform_subscription, account: account, plan: build(:platform_plan, features: %{user_management: true}))
      {:ok, %{data: %{"createGroup" => create}}} = run_query("""
        mutation Create($attributes: GroupAttributes!) {
          createGroup(attributes: $attributes) {
            name
          }
        }
      """, %{"attributes" => %{"name" => "group"}}, %{current_user: Core.Services.Rbac.preload(user)})

      assert create["name"] == "group"
    end

    test "fails if feature is disabled", %{user: user} do
      {:ok, %{errors: [_ | _]}} = run_query("""
        mutation Create($attributes: GroupAttributes!) {
          createGroup(attributes: $attributes) {
            name
          }
        }
      """, %{"attributes" => %{"name" => "group"}}, %{current_user: Core.Services.Rbac.preload(user)})
    end
  end

  describe "updateGroup" do
    setup [:setup_root_user]

    test "updates a group", %{user: user, account: account} do
      group = insert(:group, account: account)
      {:ok, %{data: %{"updateGroup" => create}}} = run_query("""
        mutation Update($groupId: ID!, $attributes: GroupAttributes!) {
          updateGroup(groupId: $groupId, attributes: $attributes) {
            name
          }
        }
      """, %{"groupId" => group.id, "attributes" => %{"name" => "group"}}, %{current_user: user})

      assert create["name"] == "group"
    end
  end

  describe "deleteGroup" do
    setup [:setup_root_user]

    test "deletes a group", %{user: user, account: account} do
      group = insert(:group, account: account)
      {:ok, %{data: %{"deleteGroup" => create}}} = run_query("""
        mutation Update($groupId: ID!) {
          deleteGroup(groupId: $groupId) {
            id
          }
        }
      """, %{"groupId" => group.id}, %{current_user: user})

      assert create["id"] == group.id

      refute refetch(group)
    end
  end

  describe "createGroupMember" do
    setup [:setup_root_user]

    test "creates a group member", %{user: user, account: account} do
      group = insert(:group, account: account)
      other = insert(:user, account: account)
      {:ok, %{data: %{"createGroupMember" => create}}} = run_query("""
        mutation Update($groupId: ID!, $userId: ID!) {
          createGroupMember(groupId: $groupId, userId: $userId) {
            id
            user { id }
            group { id }
          }
        }
      """, %{"groupId" => group.id, "userId" => other.id}, %{current_user: user})

      assert create["group"]["id"] == group.id
      assert create["user"]["id"] == other.id
    end
  end

  describe "deleteGroupMember" do
    setup [:setup_root_user]

    test "creates a group member", %{user: user, account: account} do
      group = insert(:group, account: account)
      member = insert(:group_member, group: group)
      {:ok, %{data: %{"deleteGroupMember" => delete}}} = run_query("""
        mutation Update($groupId: ID!, $userId: ID!) {
          deleteGroupMember(groupId: $groupId, userId: $userId) {
            id
            user { id }
            group { id }
          }
        }
      """, %{"groupId" => group.id, "userId" => member.user.id}, %{current_user: user})

      assert delete["id"] == member.id
      assert delete["group"]["id"] == group.id
      assert delete["user"]["id"] == member.user.id

      refute refetch(member)
    end
  end

  describe "createRole" do
    setup [:setup_root_user]

    test "it can create roles", %{user: user, account: account} do
      insert(:platform_subscription, account: account, plan: build(:platform_plan, features: %{user_management: true}))
      {:ok, %{data: %{"createRole" => create}}} = run_query("""
        mutation Create($attributes: RoleAttributes!) {
          createRole(attributes: $attributes) {
            name
            repositories
            permissions
          }
        }
      """, %{"attributes" => %{
        "name" => "role", "repositories" => ["*"], "permissions" => ["INSTALL"]
      }}, %{current_user: Core.Services.Rbac.preload(user)})

      assert create["name"] == "role"
      assert create["repositories"] == ["*"]
      assert create["permissions"] == ["INSTALL"]
    end

    test "it can fail if the feature is not enabled", %{user: user} do
      {:ok, %{errors: [_ | _]}} = run_query("""
        mutation Create($attributes: RoleAttributes!) {
          createRole(attributes: $attributes) {
            name
            repositories
            permissions
          }
        }
      """, %{"attributes" => %{
        "name" => "role", "repositories" => ["*"], "permissions" => ["INSTALL"]
      }}, %{current_user: Core.Services.Rbac.preload(user)})
    end
  end

  describe "updateRole" do
    setup [:setup_root_user]

    test "it can create roles", %{user: user, account: account} do
      role = insert(:role, account: account)
      {:ok, %{data: %{"updateRole" => update}}} = run_query("""
        mutation Update($attributes: RoleAttributes!, $id: ID!) {
          updateRole(id: $id, attributes: $attributes) {
            id
            name
            repositories
            permissions
          }
        }
      """, %{
        "id" => role.id,
        "attributes" => %{
          "name" => "role", "repositories" => ["*"], "permissions" => ["INSTALL"]
        }
      }, %{current_user: user})

      assert update["id"] == role.id
      assert update["name"] == "role"
      assert update["repositories"] == ["*"]
      assert update["permissions"] == ["INSTALL"]
    end
  end

  describe "deleteRole" do
    setup [:setup_root_user]

    test "it can create roles", %{user: user, account: account} do
      role = insert(:role, account: account)
      {:ok, %{data: %{"deleteRole" => delete}}} = run_query("""
        mutation Create($id: ID!) {
          deleteRole(id: $id) {
            id
          }
        }
      """, %{"id" => role.id}, %{current_user: user})

      assert delete["id"] == role.id
      refute refetch(role)
    end
  end

  describe "createIntegrationWebhook" do
    setup [:setup_root_user]

    test "it can create webhooks", %{user: user} do
      {:ok, %{data: %{"createIntegrationWebhook" => create}}} = run_query("""
        mutation Create($attrs: IntegrationWebhookAttributes!) {
          createIntegrationWebhook(attributes: $attrs) {
            id
            url
          }
        }
      """, %{"attrs" => %{
        "name" => "hook",
        "url" => "https://example.com",
        "actions" => ["incident.create"]
      }}, %{current_user: user})

      assert create["id"]
      assert create["url"] == "https://example.com"
    end
  end

  describe "updateIntegrationWebhook" do
    setup [:setup_root_user]

    test "it can create webhooks", %{user: user, account: account} do
      webhook = insert(:integration_webhook, account: account)
      {:ok, %{data: %{"updateIntegrationWebhook" => update}}} = run_query("""
        mutation Create($id: ID!, $attrs: IntegrationWebhookAttributes!) {
          updateIntegrationWebhook(id: $id, attributes: $attrs) {
            id
            url
          }
        }
      """, %{"id" => webhook.id, "attrs" => %{
        "name" => "hook",
        "url" => "https://example.com",
        "actions" => ["incident.create"]
      }}, %{current_user: user})

      assert update["id"] == webhook.id
      assert update["url"] == "https://example.com"
    end
  end

  describe "deleteIntegrationWebhook" do
    setup [:setup_root_user]

    test "it can create webhooks", %{user: user, account: account} do
      webhook = insert(:integration_webhook, account: account)
      {:ok, %{data: %{"deleteIntegrationWebhook" => update}}} = run_query("""
        mutation Create($id: ID!) {
          deleteIntegrationWebhook(id: $id) {
            id
          }
        }
      """, %{"id" => webhook.id}, %{current_user: user})

      assert update["id"] == webhook.id
      refute refetch(webhook)
    end
  end

  describe "createOauthIntegration" do
    setup [:setup_root_user]

    test "It can create an oauth integration", %{user: user} do
      expect(HTTPoison, :post, fn "https://zoom.us/oauth/token" <> _, _, _ ->
        {:ok, %{status_code: 200, body: Jason.encode!(%{access_token: "at", refresh_token: "rt", expires_in: 3600})}}
      end)

      {:ok, %{data: %{"createOauthIntegration" => create}}} = run_query("""
        mutation Create($attrs: OauthAttributes!) {
          createOauthIntegration(attributes: $attrs) { id }
        }
      """, %{"attrs" => %{"redirectUri" => "uri", "code" => "code", "service" => "ZOOM"}}, %{current_user: user})

      assert create["id"]
    end
  end

  describe "createZoom" do
    setup [:setup_root_user]

    test "It can create zoom meetings", %{user: user, account: account} do
      incident = insert(:incident, creator: user)
      insert(:oauth_integration, account: account)
      expect(HTTPoison, :post, fn "https://api.zoom.us/v2/users/me/meetings", _, _ ->
        {:ok, %{status_code: 201, body: Jason.encode!(%{join_url: "https://zoom.us/j/1100000"})}}
      end)

      {:ok, %{data: %{"createZoom" => create}}} = run_query("""
        mutation Create($attrs: MeetingAttributes!) {
          createZoom(attributes: $attrs) {
            joinUrl
            password
          }
        }
      """, %{"attrs" => %{"incidentId" => incident.id, "topic" => "topic"}}, %{current_user: user})

      assert create["joinUrl"] == "https://zoom.us/j/1100000"
      assert create["password"]
    end
  end
end
