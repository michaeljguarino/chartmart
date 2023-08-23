defmodule Core.Schema.ChartInstallation do
  use Piazza.Ecto.Schema
  alias Core.Schema.{Chart, Installation, Version}

  schema "chart_installations" do
    field :locked, :boolean, default: false
    field :synced, :boolean, default: false

    belongs_to :installation, Installation
    belongs_to :chart,        Chart
    belongs_to :version,      Version

    timestamps()
  end

  def for_installation(query \\ __MODULE__, inst_id) do
    from(ci in query, where: ci.installation_id == ^inst_id)
  end

  def with_auto_upgrade(query \\ __MODULE__, tags) do
    tags = Enum.map(tags, & &1.tag)
    from(ci in query,
      join: inst in assoc(ci, :installation),
      where: inst.auto_upgrade and inst.track_tag in ^tags)
  end

  def ignore_version(query \\ __MODULE__, version_id) do
    from(ci in query,
      where: ci.version_id != ^version_id)
  end

  def for_images(query \\ __MODULE__, img_ids) do
    from(ci in query,
      join: v in assoc(ci, :version),
      join: id in assoc(v, :image_dependencies),
      where: id.image_id in ^img_ids,
      distinct: true
    )
  end

  def for_chart(query \\ __MODULE__, chart_id) do
    from(ci in query,
      join: c in assoc(ci, :chart), as: :chart,
      where: c.id == ^chart_id)
  end

  def for_repo(query \\ __MODULE__, repo_id) do
    from(ci in query,
      join: c in assoc(ci, :chart), as: :chart,
      where: c.repository_id == ^repo_id)
  end

  def for_repo_name(query \\ __MODULE__, name) do
    from(ci in query,
      join: c in assoc(ci, :chart), as: :chart,
      join: r in assoc(c, :repository), as: :repo,
      where: r.name == ^name)
  end

  def for_chart_name(query \\ __MODULE__, name)
  def for_chart_name(query, names) when is_list(names) do
    from([ci, chart: c] in query,
      where: c.name in ^names)
  end
  def for_chart_name(query, name) do
    from([ci, chart: c] in query,
      where: c.name == ^name)
  end

  def for_user(query, user_id) do
    from([ci, chart: c] in query,
      join: inst in Installation,
        on: inst.id == ci.installation_id and c.repository_id == inst.repository_id,
      where: inst.user_id == ^user_id
    )
  end

  def ordered(query \\ __MODULE__, order \\ [asc: :id]),
    do: from(cv in query, order_by: ^order)

  def preload(query \\ __MODULE__, preloads),
    do: from(cv in query, preload: ^preloads)

  @valid ~w(installation_id chart_id version_id synced)a

  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @valid)
    |> validate_required([:installation_id, :chart_id, :version_id])
    |> foreign_key_constraint(:installation_id)
    |> foreign_key_constraint(:chart_id)
    |> foreign_key_constraint(:version_id)
    |> unique_constraint(:version_id, name: index_name(:chart_installations, [:installation_id, :chart_id]))
  end
end
