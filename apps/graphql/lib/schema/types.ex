defmodule GraphQl.Schema.Types do
  use GraphQl.Schema.Base
  alias GraphQl.Resolvers.{
    User,
    Repository,
    Chart,
    Terraform,
    Docker,
    Recipe,
    Payments
  }

  object :user do
    field :id,          non_null(:id)
    field :name,        non_null(:string)
    field :email,       non_null(:string)
    field :customer_id, :string
    field :publisher, :publisher, resolve: dataloader(User)

    field :jwt, :string, resolve: fn
      %{id: id, jwt: jwt}, _, %{context: %{current_user: %{id: id}}} -> {:ok, jwt}
      _, _, %{context: %{current_user: %{}}} -> {:error, "you can only query your own jwt"}
      %{jwt: jwt}, _, _ -> {:ok, jwt}
    end

    field :avatar, :string, resolve: fn
      user, _, _ -> {:ok, Core.Storage.url({user.avatar, user}, :original)}
    end

    field :background_color, :string, resolve: fn
      user, _, _ -> {:ok, User.background_color(user)}
    end

    timestamps()
  end

  object :persisted_token do
    field :id,    :id
    field :token, :string

    timestamps()
  end

  object :publisher do
    field :id,           :id
    field :name,         non_null(:string)
    field :description,  :string
    field :account_id,   :string
    field :owner,        :user, resolve: dataloader(User)

    field :avatar, :string, resolve: fn
      publisher, _, _ -> {:ok, Core.Storage.url({publisher.avatar, publisher}, :original)}
    end

    timestamps()
  end

  object :repository do
    field :id,            :id
    field :name,          non_null(:string)
    field :description,   :string
    field :documentation, :string
    field :publisher,     :publisher, resolve: dataloader(User)
    field :plans,         list_of(:plan), resolve: dataloader(Payments)
    field :tags,          list_of(:tag), resolve: dataloader(Repository)

    field :icon, :string, resolve: fn
      repo, _, _ -> {:ok, Core.Storage.url({repo.icon, repo}, :original)}
    end

    field :installation, :installation, resolve: fn
      repo, _, context -> Repository.resolve_installation(repo, context)
    end

    field :editable, :boolean, resolve: fn
      repo, _, %{context: %{current_user: user}} -> Repository.editable(repo, user)
    end

    field :public_key, :string, resolve: fn
      repo, _, %{context: %{current_user: user}} -> Repository.resolve_public_key(repo, user)
    end

    timestamps()
  end

  object :chart do
    field :id,             :id
    field :name,           non_null(:string)
    field :description,    :string
    field :latest_version, :string
    field :repository,     :repository, resolve: dataloader(Repository)
    field :dependencies,   :dependencies

    field :installation, :chart_installation, resolve: fn
      chart, _, %{context: %{current_user: user}} ->
        Chart.resolve_chart_installation(chart, user)
    end

    timestamps()
  end

  object :version do
    field :id,              :id
    field :version,         non_null(:string)
    field :readme,          :string
    field :values_template, :string
    field :helm,            :map

    field :chart, :chart, resolve: dataloader(Chart)

    timestamps()
  end

  object :installation do
    field :id,           :id
    field :context,      :map
    field :repository,   :repository, resolve: dataloader(Repository)
    field :user,         :user, resolve: dataloader(User)
    field :auto_upgrade, :boolean

    field :license, :string, resolve: fn
      installation, _, _ -> Core.Services.Repositories.generate_license(installation)
    end

    timestamps()
  end

  object :chart_installation do
    field :id,           :id
    field :chart,        :chart, resolve: dataloader(Chart)
    field :version,      :version, resolve: dataloader(Chart)
    field :installation, :installation, resolve: dataloader(Repository)

    timestamps()
  end

  object :terraform_installation do
    field :id,           :id
    field :terraform,    :terraform, resolve: dataloader(Terraform)
    field :installation, :installation, resolve: dataloader(Repository)

    timestamps()
  end

  object :docker_repository do
    field :id,         :id
    field :name,       :string
    field :repository, :repository, resolve: dataloader(Repository)

    timestamps()
  end

  object :docker_image do
    field :id,     :id
    field :tag,    :string
    field :digest, :string

    field :docker_repository, :docker_repository, resolve: dataloader(Docker)

    timestamps()
  end

  object :dependencies do
    field :dependencies, list_of(:dependency)
    field :providers, list_of(:provider)
    field :wirings, :wirings
  end

  enum :dependency_type do
    value :terraform
    value :helm
  end

  object :dependency do
    field :type, :dependency_type
    field :name, :string
    field :repo, :string
  end

  object :closure do
    field :helm, list_of(:chart)
    field :terraform, list_of(:terraform)
  end

  object :wirings do
    field :terraform, :map
    field :helm, :map
  end

  object :webhook do
    field :id,     :id
    field :url,    :string
    field :secret, :string
    field :user,   :user, resolve: dataloader(User)

    timestamps()
  end

  object :terraform do
    field :id,              :id
    field :name,            :string
    field :readme,          :string
    field :description,     :string
    field :values_template, :string
    field :dependencies,    :dependencies

    field :package,     :string, resolve: fn
      repo, _, _ -> {:ok, Core.Storage.url({repo.package, repo}, :original)}
    end
    field :repository,  :repository, resolve: dataloader(Repository)
    field :editable,    :boolean, resolve: fn
      tf, _, %{context: %{current_user: user}} -> Terraform.editable(tf, user)
    end

    field :installation, :terraform_installation, resolve: fn
      terraform, _, %{context: %{current_user: user}} ->
        Terraform.resolve_terraform_installation(terraform, user)
    end

    timestamps()
  end

  object :webhook_response do
    field :status_code, non_null(:integer)
    field :body,        :string
    field :headers,     :map
  end

  object :recipe do
    field :id,              :id
    field :name,            non_null(:string)
    field :description,     :string
    field :provider,        :provider
    field :repository,      :repository, resolve: dataloader(Repository)
    field :recipe_sections, list_of(:recipe_section), resolve: dataloader(Recipe)

    timestamps()
  end

  enum :provider do
    value :gcp
    value :aws
    value :azure
  end

  object :recipe_section do
    field :id,           :id
    field :repository,   :repository, resolve: dataloader(Repository)
    field :recipe,       :recipe, resolve: dataloader(Recipe)
    field :index,        :integer
    field :recipe_items, list_of(:recipe_item), resolve: dataloader(Recipe)

    timestamps()
  end

  object :recipe_item do
    field :id,             :id
    field :chart,          :chart, resolve: dataloader(Chart)
    field :terraform,      :terraform, resolve: dataloader(Terraform)
    field :recipe_section, :recipe_section, resolve: dataloader(Recipe)
    field :configuration,  list_of(:recipe_configuration)

    timestamps()
  end

  enum :datatype do
    value :int
    value :bool
    value :string
    value :object
  end

  object :recipe_configuration do
    field :type,          :datatype
    field :name,          :string
    field :default,       :string
    field :documentation, :string
    field :placeholder,   :string
  end

  object :integration do
    field :id,          non_null(:id)
    field :name,        non_null(:string)
    field :source_url,  :string
    field :description, :string
    field :spec,        :map

    field :icon, :string, resolve: fn
      integration, _, _ -> {:ok, Core.Storage.url({integration.icon, integration}, :original)}
    end

    field :repository, :repository, resolve: dataloader(Repository)
    field :publisher,  :publisher, resolve: dataloader(User)
    field :tags,       list_of(:tag), resolve: dataloader(Repository)

    timestamps()
  end

  object :plan do
    field :id,         non_null(:id)
    field :name,       non_null(:string)
    field :default,    :boolean
    field :visible,    non_null(:boolean)
    field :cost,       non_null(:integer)
    field :period,     :string
    field :line_items, :plan_line_items

    timestamps()
  end

  object :repository_subscription do
    field :id,           non_null(:id)
    field :external_id,  :string
    field :customer_id,  :string
    field :line_items,   :subscription_line_items
    field :installation, :installation, resolve: dataloader(Repository)
    field :plan,         :plan, resolve: dataloader(Payments)
  end

  object :tag do
    field :id,  non_null(:id)
    field :tag, non_null(:string)
  end

  enum :tag_group do
    value :integrations
    value :repositories
  end

  object :grouped_tag do
    field :tag,   non_null(:string)
    field :count, non_null(:integer)
  end

  object :plan_line_items do
    field :included, list_of(:limit)
    field :items,    list_of(:line_item)
  end

  object :subscription_line_items do
    field :items, list_of(:limit)
  end

  object :line_item do
    field :name,      non_null(:string)
    field :dimension, non_null(:string)
    field :cost,      non_null(:integer)
    field :period,    :string
  end

  object :limit do
    field :dimension, non_null(:string)
    field :quantity,  non_null(:integer)
  end

  connection node_type: :user
  connection node_type: :publisher
  connection node_type: :repository
  connection node_type: :chart
  connection node_type: :version
  connection node_type: :installation
  connection node_type: :integration
  connection node_type: :terraform
  connection node_type: :terraform_installation
  connection node_type: :chart_installation
  connection node_type: :persisted_token
  connection node_type: :docker_repository
  connection node_type: :docker_image
  connection node_type: :webhook
  connection node_type: :recipe
  connection node_type: :grouped_tag
end