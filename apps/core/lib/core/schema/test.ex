defmodule Core.Schema.Test do
  use Piazza.Ecto.Schema
  alias Core.Schema.{Repository, User, TestBinding, TestStep}

  @expiry 1 # hour

  defenum Status, queued: 0, running: 1, succeeded: 2, failed: 3

  schema "tests" do
    field :name,        :string
    field :source_tag,  :string
    field :promote_tag, :string
    field :tags,        {:array, :string}
    field :status,      Status

    belongs_to :repository, Repository
    belongs_to :creator,    User

    has_many :bindings, TestBinding
    has_many :steps,    TestStep

    timestamps()
  end

  def stale(query \\ __MODULE__) do
    expiry = Timex.now() |> Timex.shift(hours: -@expiry)
    from(t in query, where: t.status not in ^[:succeeded, :failed] and t.inserted_at < ^expiry)
  end

  def for_repository(query \\ __MODULE__, repo_id) do
    from(t in query, where: t.repository_id == ^repo_id)
  end

  def for_version(query \\ __MODULE__, vsn_id) do
    from(t in query,
      join: b in assoc(t, :bindings),
      where: b.version_id == ^vsn_id
    )
  end

  def ordered(query \\ __MODULE__, order \\ [desc: :inserted_at]) do
    from(t in query, order_by: ^order)
  end

  @valid ~w(name source_tag promote_tag status repository_id creator_id tags)a

  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @valid)
    |> cast_assoc(:bindings)
    |> cast_assoc(:steps)
    |> foreign_key_constraint(:repository_id)
    |> foreign_key_constraint(:creator_id)
    |> validate_required([:status, :repository_id, :creator_id, :promote_tag])
  end
end
