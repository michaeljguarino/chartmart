defmodule Email.Builder.LockedInstallation do
  use Email.Builder.Base
  alias Core.Schema.{Dependencies, Version}

  def email(inst) do
    %{installation: %{user: user}} = inst = Core.Repo.preload(inst, [:version, installation: [:user, :repository]])

    active_cluster(user, fn ->
      repo = inst.installation.repository
      base_email()
      |> to(expand_service_account(user))
      |> subject("Manual changes need to be applied for your #{repo.name} installation")
      |> assign(:type, inst_type(inst))
      |> assign(:user, user)
      |> assign(:installation, inst)
      |> assign(:deps, inst.version.dependencies)
      |> assign(:instructions, instructions(inst.version))
      |> assign(:repo, repo)
      |> render(:locked_installation)
    end)
  end

  defp instructions(%Version{dependencies: %Dependencies{instructions: %Dependencies.ChangeInstructions{} = instructions}}),
    do: instructions
  defp instructions(_), do: %{script: nil, instructions: nil}

  defp inst_type(%{chart: _}), do: :chart
  defp inst_type(%{terraform: _}), do: :terraform
end
