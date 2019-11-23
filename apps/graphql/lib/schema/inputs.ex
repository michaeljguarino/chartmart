defmodule GraphQl.Schema.Inputs do
  use Absinthe.Schema.Notation

  import_types Absinthe.Plug.Types
  import_types GraphQl.Schemas.Upload

  input_object :user_attributes do
    field :name,     :string
    field :email,    :string
    field :password, :string
    field :avatar,   :upload_or_url
  end

  input_object :publisher_attributes do
    field :name,        :string
    field :description, :string
    field :avatar,      :upload_or_url
  end

  input_object :repository_attributes do
    field :name,          :string
    field :description,   :string
    field :documentation, :string
    field :icon,          :upload_or_url
  end

  input_object :installation_attributes do
    field :context,      :yml
    field :auto_upgrade, :boolean
  end

  input_object :terraform_attributes do
    field :name,         :string
    field :description,  :string
    field :package,      :upload_or_url
    field :dependencies, :yml
  end

  input_object :chart_installation_attributes do
    field :chart_id,   :id
    field :version_id, :id
  end

  input_object :terraform_installation_attributes do
    field :terraform_id, :id
  end
end