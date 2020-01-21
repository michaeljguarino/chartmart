defmodule Core.Services.Dependencies do
  use Core.Services.Base
  alias Core.Schema.{
    TerraformInstallation,
    Terraform,
    Chart,
    ChartInstallation,
    Dependencies,
    User
  }

  @doc """
  Determines if the user's installations has met the given dependencies
  """
  @spec valid?(Dependencies.t | Dependencies.Dependency.t | nil, User.t) :: boolean
  def valid?(nil, _), do: true
  def valid?(%Dependencies{dependencies: nil}, _), do: true
  def valid?(%Dependencies{dependencies: deps}, user) when is_list(deps),
    do: Enum.all?(deps, &valid?(&1, user))
  def valid?(%Dependencies.Dependency{type: :terraform, repo: repo} = dep, %User{id: user_id}) do
    TerraformInstallation.for_repo_name(repo)
    |> TerraformInstallation.for_terraform_name(find_names(dep))
    |> TerraformInstallation.for_user(user_id)
    |> Core.Repo.exists?()
  end
  def valid?(%Dependencies.Dependency{type: :helm, repo: repo} = dep, %User{id: user_id}) do
    ChartInstallation.for_repo_name(repo)
    |> ChartInstallation.for_chart_name(find_names(dep))
    |> ChartInstallation.for_user(user_id)
    |> Core.Repo.exists?()
  end
  def valid?(_, _), do: false

  @doc """
  Same as valid? except extracts and returns the first dep that fails.
  """
  @spec validate(nil | Dependencies.t | [Dependencies.Dependency.t], User.t) :: :pass | {:error, {:missing_dep, term}}
  def validate(nil, _), do: :pass
  def validate(%{dependencies: nil}, _), do: :pass
  def validate(%{dependencies: deps}, user) when is_list(deps),
    do: validate(deps, user)
  def validate([dep | rest], user) do
    case valid?(dep, user) do
      true -> validate(rest, user)
      false -> {:error, {:missing_dep, dep}}
    end
  end
  def validate([], _), do: :pass

  @doc """
  Converts a validation error to a gql suitable response
  """
  @spec pretty_print({:error, {:missing_dep, %{type: :terraform | :helm, repo: binary}}}) :: {:error, binary}
  def pretty_print({:error, {:missing_dep, %{type: :terraform, repo: repo} = dep}}),
    do: {:error, "Missing #{mod(dep)} terraform module #{pretty_name(dep)} from repo #{repo}"}
  def pretty_print({:error, {:missing_dep, %{type: :helm, repo: repo} = dep}}),
    do: {:error, "Missing #{mod(dep)} helm chart #{pretty_name(dep)} from repo #{repo}"}

  defp mod(%{any: [_ | _]}), do: "any"
  defp mod(_), do: ""

  defp pretty_name(%{any: [_ | _] = names}), do: "in [#{Enum.join(names, ", ")}]"
  defp pretty_name(%{name: name}), do: name

  @doc """
  Extracts all charts/tf modules which are transitive dependencies
  """
  @spec closure(Dependencies.t | Dependencies.Dependency.t | nil) :: %{terraform: [Terraform.t], helm: [Helm.t]}
  def closure(%{dependencies: dependencies}), do: closure(dependencies)
  def closure(nil), do: []
  def closure(deps) when is_list(deps), do: closure(deps, MapSet.new(), [])

  defp closure([], _, acc), do: acc
  defp closure(deps, seen, acc) do
    level = traverse_level(deps, seen)
    seen = Enum.into(level, seen, fn
      %Terraform{name: name, repository: %{name: repo}} -> {:terraform, repo, name}
      %Chart{name: name, repository: %{name: repo}} -> {:helm, repo, name}
    end)

    level
    |> Enum.filter(& &1.dependencies && &1.dependencies.dependencies)
    |> Enum.flat_map(& &1.dependencies.dependencies)
    |> closure(seen, level ++ acc)
  end

  defp traverse_level(deps, seen) do
    deps
    |> Enum.reject(&MapSet.member?(seen, {&1.type, &1.repo, &1.name}))
    |> Enum.group_by(& {&1.type, &1.repo})
    |> Enum.reduce(Parallax.new(), fn {{type, repo} = key, group}, operation ->
      Parallax.operation(operation, key, fn ->
        find_dependencies(type, repo, Enum.flat_map(group, &find_names/1))
      end)
    end)
    |> Parallax.execute()
    |> Enum.flat_map(fn {_, results} -> results end)
  end

  defp find_names(%{any: [_ | _] = names}), do: names
  defp find_names(%{name: name}), do: [name]

  defp find_dependencies(:terraform, repo_name, names) do
    Terraform.for_repository_name(repo_name)
    |> Terraform.for_name(names)
    |> Terraform.preloaded()
    |> Core.Repo.all()
  end
  defp find_dependencies(:helm, repo_name, names) do
    Chart.for_repository_name(repo_name)
    |> Chart.for_name(names)
    |> Chart.preloaded()
    |> Core.Repo.all()
  end

  def extract_dependencies(tar, filename) do
    with deps when is_binary(deps) <- extract_tar_file(tar, filename),
          {:ok, map} <- YamlElixir.read_from_string(deps) do
      {:ok, map}
    else
      {:error, _} = error -> error
      _ -> {:ok, nil}
    end
  end

  defp extract_tar_file(tar, val_template) do
    case Enum.find(tar, &elem(&1, 0) == val_template) do
      {_, template} -> template
      _ -> nil
    end
  end
end