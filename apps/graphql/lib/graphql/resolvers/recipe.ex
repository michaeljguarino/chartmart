defmodule GraphQl.Resolvers.Recipe do
  use GraphQl.Resolvers.Base, model: Core.Schema.Recipe
  alias Core.Schema.{RecipeSection, RecipeItem, Stack, StackCollection, StackRecipe}
  alias Core.Services.{Recipes, Repositories}

  def query(RecipeItem, _), do: RecipeItem
  def query(RecipeSection, _), do: RecipeSection
  def query(StackCollection, _), do: StackCollection
  def query(StackRecipe, _), do: StackRecipe
  def query(Stack, _), do: Stack
  def query(_, _), do: Recipe

  def list_recipes(args, %{context: %{repo: %{id: repo_id}}}) do
    Recipe.for_repository(repo_id)
    |> Recipe.public()
    |> maybe_filter_provider(args)
    |> Recipe.ordered()
    |> paginate(args)
  end

  def list_stacks(args, %{context: ctx}) do
    Stack.ordered()
    |> Stack.permanent()
    |> stack_filters(args, ctx[:current_user])
    |> paginate(args)
  end

  defp maybe_filter_provider(q, %{provider: p}) when not is_nil(p),
    do: Recipe.for_provider(q, p)
  defp maybe_filter_provider(q, _), do: q

  defp stack_filters(q, %{featured: true}, _), do: Stack.featured(q)
  defp stack_filters(q, _, %{account_id: aid}), do: Stack.for_account(q, aid)
  defp stack_filters(q, _, _), do: Stack.featured(q)

  def resolve_stack(%{name: name, provider: provider}, %{context: ctx}) do
    stack = Recipes.get_stack!(name)
    with {:ok, stack} <- Recipes.accessible(stack, ctx[:current_user]) do
      Recipes.hydrate(stack, provider)
    end
  end

  def resolve_recipe(%{id: id}, %{context: %{current_user: user}}) when is_binary(id) do
    Recipes.get!(id)
    |> Recipes.hydrate()
    |> accessible(user)
  end

  def resolve_recipe(%{name: name, repo: repo}, %{context: %{current_user: user}}) do
    Recipes.get_by_repo_and_name!(repo, name)
    |> Recipes.hydrate()
    |> accessible(user)
  end

  def accessible(%Recipe{} = recipe, user), do: Core.Policies.Recipe.allow(recipe, user, :access)
  def accessible(nil, _), do: {:error, "recipe not found"}

  def create_recipe(%{repository_id: repo_id, attributes: attrs}, %{context: %{current_user: user}})
    when is_binary(repo_id), do: Recipes.upsert(attrs, repo_id, user)
  def create_recipe(%{repository_name: name} = args, context) do
    repo = Repositories.get_repository_by_name!(name)

    Map.put(args, :repository_id, repo.id)
    |> create_recipe(context)
  end

  def delete_recipe(%{id: id}, %{context: %{current_user: user}}),
    do: Recipes.delete(id, user)

  def install_recipe(%{recipe_id: recipe_id, context: context}, %{context: %{current_user: user}}),
    do: Recipes.install(recipe_id, context, user)

  def install_stack(%{name: stack, provider: provider}, %{context: %{current_user: user}}),
    do: Recipes.install_stack(stack, provider, user)

  def upsert_stack(%{attributes: %{name: name} = attrs}, %{context: %{current_user: user}}),
    do: Recipes.upsert_stack(attrs, name, user)

  def delete_stack(%{name: name}, %{context: %{current_user: user}}),
    do: Recipes.delete_stack(name, user)

  def quick_stack(%{repository_ids: ids, provider: provider}, %{context: %{current_user: user}}),
    do: Recipes.quick_stack(ids, provider, user)
end
