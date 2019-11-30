defmodule Core.Schema.Version do
  use Piazza.Ecto.Schema
  alias Core.Schema.{Chart, Dependencies}

  schema "versions" do
    field :version, :string
    field :helm, :map
    field :readme, :string
    field :values_template, :string

    embeds_one :dependencies, Dependencies, on_replace: :update
    belongs_to :chart, Chart

    timestamps()
  end

  def for_chart(query \\ __MODULE__, chart_id),
    do: from(v in query, where: v.chart_id == ^chart_id)

  def ordered(query \\ __MODULE__, order \\ [desc: :inserted_at]),
    do: from(v in query, order_by: ^order)

  @valid ~w(version chart_id readme values_template)a

  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @valid)
    |> cast_embed(:dependencies)
    |> validate_required([:version, :chart_id])
    |> unique_constraint(:version, name: index_name(:charts, [:chart_id, :version]))
    |> foreign_key_constraint(:chart_id)
  end

  def helm_changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, [:helm | @valid])
    |> cast_embed(:dependencies)
  end
end