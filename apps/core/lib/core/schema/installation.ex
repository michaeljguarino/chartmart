defmodule Core.Schema.Installation do
  use Piazza.Ecto.Schema
  alias Core.Schema.{Repository, User, Subscription, OIDCProvider}

  defmodule Policy do
    use Piazza.Ecto.Schema

    embedded_schema do
      field :free, :boolean, default: true
    end

    @valid ~w(free)

    def changeset(model, attrs \\ %{}) do
      model
      |> cast(attrs, @valid)
    end
  end

  defenum Source, default: 0, shell: 1, demo: 2

  schema "installations" do
    field :context,      :map
    field :source,       Source, default: :default
    field :auto_upgrade, :boolean, default: false
    field :track_tag,    :string, default: "latest"
    field :license_key,  :string
    field :pinged_at,    :utc_datetime_usec
    field :tag_updated,  :boolean, virtual: true, default: false

    embeds_one :policy,     Policy, on_replace: :update
    belongs_to :user,       User
    belongs_to :repository, Repository
    has_one :subscription,  Subscription
    has_one :oidc_provider, OIDCProvider

    timestamps()
  end

  def ordered(query \\ __MODULE__, order \\ [desc: :inserted_at]),
    do: from(i in query, order_by: ^order)

  def for_user(query \\ __MODULE__, user_id),
    do: from(i in query, where: i.user_id == ^user_id)

  def tracking(query \\ __MODULE__, tag) do
    from(i in query, where: i.track_tag == ^tag)
  end

  @valid ~w(user_id repository_id context auto_upgrade track_tag source)a

  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @valid)
    |> validate_required([:user_id, :repository_id])
    |> unique_constraint(:repository_id, name: index_name(:installations, [:user_id, :repository_id]))
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:repository_id)
    |> put_new_change(:license_key, &gen_license_key/0)
    |> change_markers(track_tag: :tag_updated)
  end

  defp gen_license_key() do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64()
    |> String.replace("/", "")
  end
end
