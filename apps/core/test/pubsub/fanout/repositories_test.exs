defmodule Core.PubSub.Fanout.InstallationsTest do
  use Core.SchemaCase, async: true
  use Mimic
  alias Core.PubSub

  describe "InstallationDeleted" do
    test "if a user no longer has a provider, it will nilify" do
      %{user: user} = inst = insert(:installation, user: build(:user, provider: :gcp))

      event = %PubSub.InstallationDeleted{item: inst, actor: user}
      {:ok, update} = PubSub.Fanout.fanout(event)

      assert update.id == user.id
      refute update.provider
    end
  end

  describe "InstallationUpdated" do
    test "it will create an upgrade if the tag has been updated" do
      inst = insert(:installation, tag_updated: true, track_tag: "tag")
      queue = insert(:upgrade_queue, user: inst.user)

      event = %PubSub.InstallationUpdated{item: inst}
      {:ok, [upgrade]} = PubSub.Fanout.fanout(event)

      assert upgrade.queue_id == queue.id
      assert upgrade.repository_id == inst.repository_id
      assert upgrade.message == "Set release channel to tag"
    end

    test "it will ignore if there was no tag update" do
      inst = insert(:installation)
      insert(:upgrade_queue, user: inst.user)

      event = %PubSub.InstallationUpdated{item: inst}
      :ok = PubSub.Fanout.fanout(event)
    end
  end

  describe "InstallationCreated" do
    test "it will set console isntalled" do
      user = insert(:user, onboarding_checklist: %{status: :new})
      inst = insert(:installation, repository: build(:repository, name: "console"))

      event = %PubSub.InstallationCreated{item: inst, actor: user}
      {:ok, update} = PubSub.Fanout.fanout(event)

      assert update.id == user.id
      assert update.onboarding_checklist.status == :console_installed
    end

    test "it will ignore if a demo project is present" do
      user = insert(:user, onboarding_checklist: %{status: :new})
      inst = insert(:installation, repository: build(:repository, name: "console"))
      insert(:demo_project, user: user)

      event = %PubSub.InstallationCreated{item: inst, actor: user}
      :ok = PubSub.Fanout.fanout(event)
    end

    test "it will ignore console when finished" do
      user = insert(:user, onboarding_checklist: %{status: :finished})
      inst = insert(:installation, repository: build(:repository, name: "console"))

      event = %PubSub.InstallationCreated{item: inst, actor: user}
      :ok = PubSub.Fanout.fanout(event)
    end

    test "it will set finished" do
      user = insert(:user, onboarding_checklist: %{status: :console_installed})
      inst = insert(:installation, repository: build(:repository, name: "airbyte"))

      event = %PubSub.InstallationCreated{item: inst, actor: user}
      {:ok, update} = PubSub.Fanout.fanout(event)

      assert update.id == user.id
      assert update.onboarding_checklist.status == :finished
    end

    test "it will ignore console deps" do
      user = insert(:user, onboarding_checklist: %{status: :console_installed})
      inst = insert(:installation, repository: build(:repository, name: "monitoring"))

      event = %PubSub.InstallationCreated{item: inst, actor: user}
      :ok = PubSub.Fanout.fanout(event)
    end
  end

  describe "RepositoryCreated" do
    test "it will fetch and persist a repositories readme" do
      repo = insert(:repository, git_url: "https://github.com/pluralsh/plural")

      event = %PubSub.RepositoryCreated{item: repo}
      {:ok, updated} = PubSub.Fanout.fanout(event)

      assert updated.id == repo.id
      assert is_binary(updated.readme)
      assert updated.main_branch == "master"
      assert updated.license
    end
  end

  describe "RepositoryUpdated" do
    test "it will fetch and persist a repositories readme" do
      repo = insert(:repository, git_url: "https://github.com/pluralsh/plural")

      event = %PubSub.RepositoryUpdated{item: repo}
      {:ok, updated} = PubSub.Fanout.fanout(event)

      assert updated.id == repo.id
      assert is_binary(updated.readme)
      assert updated.license
    end
  end

  describe "LicensePing" do
    test "if there's no ping set, it will record" do
      inst = insert(:installation)

      event = %PubSub.LicensePing{item: inst}
      {:ok, up} = PubSub.Fanout.fanout(event)

      assert up.pinged_at
    end

    test "if pinged_at is stale, it will update" do
      inst = insert(:installation, pinged_at: Timex.now() |> Timex.shift(hours: -3))

      event = %PubSub.LicensePing{item: inst}
      {:ok, up} = PubSub.Fanout.fanout(event)

      assert Timex.after?(up.pinged_at, inst.pinged_at)
    end

    test "if pinged_at is recent, it will ignore" do
      inst = insert(:installation, pinged_at: Timex.now())

      event = %PubSub.LicensePing{item: inst}
      :ok = PubSub.Fanout.fanout(event)
    end
  end
end
