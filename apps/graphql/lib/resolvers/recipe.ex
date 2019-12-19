defmodule GraphQl.Resolvers.Recipe do
  use GraphQl.Resolvers.Base, model: Core.Schema.Recipe
  alias Core.Schema.{RecipeSection, RecipeItem}
  alias Core.Services.Recipes

  def query(RecipeItem, _), do: RecipeItem
  def query(RecipeSection, _), do: RecipeSection
  def query(_, _), do: Recipe


  def list_recipes(%{repository_id: repo_id} = args, _) do
    Recipe.for_repository(repo_id)
    |> Recipe.ordered()
    |> paginate(args)
  end

  def resolve_recipe(%{id: id}, _) do
    {:ok, Recipes.get!(id) |> Recipes.hydrate()}
  end

  def create_recipe(%{repository_id: repo_id, attributes: attrs}, %{context: %{current_user: user}}),
    do: Recipes.upsert(attrs, repo_id, user)

  def install_recipe(%{recipe_id: recipe_id, context: context}, %{context: %{current_user: user}}),
    do: Recipes.install(recipe_id, context, user)
end