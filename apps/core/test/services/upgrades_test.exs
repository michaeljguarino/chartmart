defmodule Core.Services.UpgradesTest do
  use Core.SchemaCase, async: true
  alias Core.PubSub
  alias Core.Services.Upgrades

  describe "#create_queue/2" do
    test "it can create an upgrade queue for a user" do
      user = insert(:user)

      {:ok, queue} = Upgrades.create_queue(%{name: "cluster", provider: :aws}, user)

      assert queue.name == "cluster"
      assert queue.user_id == user.id

      cluster = Core.Services.Clusters.get_cluster(user.id, :aws, "cluster")
      assert queue.cluster_id == cluster.id

      assert_receive {:event, %PubSub.UpgradeQueueCreated{item: ^queue}}
    end

    test "it can upsert upgrade queues" do
      queue = insert(:upgrade_queue, name: "cluster")

      {:ok, up} = Upgrades.create_queue(%{name: "cluster", provider: :aws}, queue.user)

      assert up.id == queue.id
      assert up.name == "cluster"
      assert up.provider == :aws
      assert up.user_id == queue.user.id

      assert_receive {:event, %PubSub.UpgradeQueueUpdated{item: ^up}}
    end
  end

  describe "#delete_queue/1" do
    test "it will decrement usage transactionally" do
      account = insert(:account, cluster_count: 1)
      user = insert(:user, account: account)
      q = insert(:upgrade_queue, user: user)

      {:ok, up} = Upgrades.delete_queue(q)

      assert up.id == q.id
      account = refetch(account)
      assert account.cluster_count == 0
      assert account.usage_updated
    end
  end

  describe "#ping/2" do
    test "it will set the pinged_at timestamp" do
      queue = insert(:upgrade_queue)

      {:ok, q} = Upgrades.ping(queue)

      assert q.id == queue.id
      assert q.pinged_at

      assert_receive {:event, %PubSub.UpgradeQueueUpdated{item: ^q}}
    end

    test "it will ping the cluster too if it exists" do
      cluster = insert(:cluster)
      queue = insert(:upgrade_queue, cluster: cluster)

      {:ok, q} = Upgrades.ping(queue)

      assert q.id == queue.id
      assert q.pinged_at

      assert refetch(cluster).pinged_at

      assert_receive {:event, %PubSub.UpgradeQueueUpdated{item: ^q}}
    end
  end

  describe "#ack/2" do
    test "it'll always ack unacked q's" do
      queue = insert(:upgrade_queue)
      upgrade = insert(:upgrade)

      {:ok, q} = Upgrades.ack(upgrade.id, queue)

      assert q.acked == upgrade.id

      assert_receive {:event, %PubSub.UpgradeQueueUpdated{item: ^q}}
    end

    test "it'll ack if the new id is later" do
      queue = insert(:upgrade_queue, acked: "00000000-0000-0000-0000-000000000000")
      upgrade = insert(:upgrade)

      {:ok, q} = Upgrades.ack(upgrade.id, queue)

      assert q.acked == upgrade.id
    end

    test "it'll ignore earlier ids" do
      queue = insert(:upgrade_queue, acked: "ffffffff-ffff-ffff-ffff-ffffffffffff")
      upgrade = insert(:upgrade)

      {:error, _} = Upgrades.ack(upgrade.id, queue)
    end
  end

  describe "#create_deferred_update/3" do
    test "it can create a deferred update for a chart installation" do
      user = insert(:user)
      chart_inst = insert(:chart_installation)
      version = insert(:version, chart: chart_inst.chart)

      {:ok, deferred} = Upgrades.create_deferred_update(version.id, chart_inst, user)

      assert deferred.user_id == user.id
      assert deferred.version_id == version.id
      assert deferred.chart_installation_id == chart_inst.id
      assert deferred.dequeue_at
    end

    test "it can create a deferred update for a terraform installation" do
      user = insert(:user)
      tf_inst = insert(:terraform_installation)
      version = insert(:version, terraform: tf_inst.terraform)

      {:ok, deferred} = Upgrades.create_deferred_update(version.id, tf_inst, user)

      assert deferred.user_id == user.id
      assert deferred.version_id == version.id
      assert deferred.terraform_installation_id == tf_inst.id
      assert deferred.dequeue_at
    end
  end

  describe "#deferred_apply/1" do
    test "it can apply a deferred update if dependencies are satisfied" do
      chart = insert(:chart)
      other_chart = insert(:chart)
      user  = insert(:user)
      q = insert(:upgrade_queue, user: user)
      insert(:chart_installation,
        chart: chart,
        installation: insert(:installation, repository: chart.repository, user: user)
      )
      chart_inst = insert(:chart_installation,
        chart: other_chart,
        installation: insert(:installation, repository: other_chart.repository, user: user)
      )
      version = insert(:version, chart: other_chart, dependencies: %{dependencies: [
        %{type: :helm, repo: chart.repository.name, name: chart.name, providers: [:gcp]}
      ]})
      deferred = insert(:deferred_update, chart_installation: chart_inst, version: version, user: user)

      {:ok, _} = Upgrades.deferred_apply(deferred)

      refute refetch(deferred)
      assert refetch(chart_inst).version_id == version.id
      assert Core.Schema.Upgrade.for_queue(q.id)
             |> Core.Repo.exists?()
    end

    test "if the dependencies are not satisfied, it will re-enqueue the upgrade" do
      user  = insert(:user)
      chart = insert(:chart)
      insert(:upgrade_queue, user: user)
      chart_inst = insert(:chart_installation, installation: build(:installation, user: user))
      version = insert(:version, chart: chart_inst.chart, dependencies: %{dependencies: [
        %{type: :helm, repo: chart.repository.name, name: chart.name, providers: [:gcp]}
      ]})
      deferred = insert(:deferred_update, chart_installation: chart_inst, version: version, user: user)

      {:ok, deferred} = Upgrades.deferred_apply(deferred)

      assert deferred.attempts == 1
      assert Timex.after?(deferred.dequeue_at, Timex.now())
    end

    test "if an installation is locked, it will re-enqueue the upgrade" do
      user  = insert(:user)
      chart = insert(:chart)
      insert(:upgrade_queue, user: user)
      chart_inst = insert(:chart_installation, locked: true, installation: build(:installation, user: user))
      version = insert(:version, chart: chart_inst.chart, dependencies: %{dependencies: [
        %{type: :helm, repo: chart.repository.name, name: chart.name, providers: [:gcp]}
      ]})
      deferred = insert(:deferred_update, chart_installation: chart_inst, version: version, user: user)

      {:ok, deferred} = Upgrades.deferred_apply(deferred)

      assert deferred.attempts == 1
      assert Timex.after?(deferred.dequeue_at, Timex.now())
    end

    test "if a user is delinquent, it will re-enqueue the upgrade" do
      user  = insert(:user, account: build(:account, delinquent_at: Timex.now()))
      chart = insert(:chart)
      insert(:upgrade_queue, user: user)
      chart_inst = insert(:chart_installation, installation: build(:installation, user: user))
      version = insert(:version, chart: chart_inst.chart, dependencies: %{dependencies: [
        %{type: :helm, repo: chart.repository.name, name: chart.name, providers: [:gcp]}
      ]})
      deferred = insert(:deferred_update, chart_installation: chart_inst, version: version, user: user)

      {:ok, deferred} = Upgrades.deferred_apply(deferred)

      assert deferred.attempts == 1
      assert Timex.after?(deferred.dequeue_at, Timex.now())
    end
  end

  describe "#poll_deferred_updates/2" do
    test "it can poll deferred chart installation updates" do
      inst1 = insert(:chart_installation)
      deferred = insert(:deferred_update, id: uuid(0), chart_installation: inst1)
      insert(:deferred_update, id: uuid(1), chart_installation: inst1)
      deferred2 = insert(:deferred_update, id: uuid(0), chart_installation: build(:chart_installation))
      insert(:deferred_update, terraform_installation: build(:terraform_installation))

      {:ok, vals} = Upgrades.poll_deferred_updates(:chart, 10)

      assert ids_equal([deferred, deferred2], vals)
    end

    test "it will ignore updates pending promotion" do
      user = insert(:user, upgrade_to: uuid(0))
      inst1 = insert(:chart_installation, installation: build(:installation, user: user))
      insert(:deferred_update, id: uuid(1), chart_installation: inst1, user: user)
      insert(:deferred_update, id: uuid(2), chart_installation: inst1, user: user)
      deferred2 = insert(:deferred_update, id: uuid(0), chart_installation: build(:chart_installation))
      insert(:deferred_update, terraform_installation: build(:terraform_installation))

      {:ok, vals} = Upgrades.poll_deferred_updates(:chart, 10)

      assert ids_equal([deferred2], vals)
    end
  end
end
