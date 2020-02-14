defmodule WatchmanWeb.GraphQl.BuildSubscriptionTest do
  use WatchmanWeb.ChannelCase
  alias Watchman.Services.Builds
  use Mimic

  describe "buildDelta" do
    test "build create will broadcast deltas" do
      {:ok, socket} = establish_socket()
      expect(Watchman.Deployer, :wake, fn -> :ok end)

      ref = push_doc(socket, """
        subscription {
          buildDelta {
            delta
            payload {
              id
              repository
            }
          }
        }
      """)

      assert_reply(ref, :ok, %{subscriptionId: _})

      {:ok, build} = Builds.create(%{repository: "repo"})
      assert_push("subscription:data", %{result: %{data: %{"buildDelta" => delta}}})
      assert delta["delta"] == "CREATE"
      assert delta["payload"]["id"] == build.id
      assert delta["payload"]["repository"] == build.repository
    end

    test "Build modify will send UPDATE deltas" do
      {:ok, socket} = establish_socket()
      build = insert(:build)

      ref = push_doc(socket, """
        subscription {
          buildDelta {
            delta
            payload {
              id
              repository
              status
            }
          }
        }
      """)

      assert_reply(ref, :ok, %{subscriptionId: _})
      {:ok, build} = Builds.succeed(build)
      assert_push("subscription:data", %{result: %{data: %{"buildDelta" => delta}}})
      assert delta["delta"] == "UPDATE"
      assert delta["payload"]["id"] == build.id
      assert delta["payload"]["repository"] == build.repository
      assert delta["payload"]["status"] == "SUCCESSFUL"
    end
  end

  describe "commandDelta" do
    test "command creates send CREATE deltas" do
      build = insert(:build)
      {:ok, socket} = establish_socket()

      ref = push_doc(socket, """
        subscription Delta($buildId: ID!) {
          commandDelta(buildId: $buildId) {
            delta
            payload {
              id
              command
            }
          }
        }
      """, variables: %{"buildId" => build.id})

      assert_reply(ref, :ok, %{subscriptionId: _})

      {:ok, command} = Builds.create_command(%{command: "echo 'hello world'"}, build)
      assert_push("subscription:data", %{result: %{data: %{"commandDelta" => delta}}})
      assert delta["delta"] == "CREATE"
      assert delta["payload"]["id"] == command.id
      assert delta["payload"]["command"] == "echo 'hello world'"
    end

    test "command completion sends UPDATE deltas" do
      build = insert(:build)
      command = insert(:command, build: build)
      {:ok, socket} = establish_socket()

      ref = push_doc(socket, """
        subscription Delta($buildId: ID!) {
          commandDelta(buildId: $buildId) {
            delta
            payload {
              id
              exitCode
            }
          }
        }
      """, variables: %{"buildId" => build.id})

      assert_reply(ref, :ok, %{subscriptionId: _})

      {:ok, command} = Builds.complete(command, 0)
      assert_push("subscription:data", %{result: %{data: %{"commandDelta" => delta}}})
      assert delta["delta"] == "UPDATE"
      assert delta["payload"]["id"] == command.id
      assert delta["payload"]["exitCode"] == 0
    end
  end
end