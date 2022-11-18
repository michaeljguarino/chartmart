defmodule GraphQl.Schema.Test do
  use GraphQl.Schema.Base
  alias GraphQl.Resolvers.{
    Test,
    Repository,
    User
  }

  ecto_enum :test_status, Core.Schema.Test.Status

  input_object :test_attributes do
    field :name,        :string
    field :status,      :test_status
    field :promote_tag, :string
    field :tags,        list_of(:string)
    field :steps,       list_of(:test_step_attributes)
  end

  input_object :test_step_attributes do
    field :id,          :id
    field :name,        :string
    field :description, :string
    field :status,      :test_status
    field :logs,        :upload_or_url
  end

  object :test do
    field :id,          non_null(:id)
    field :name,        :string
    field :status,      non_null(:test_status)
    field :source_tag,  non_null(:string)
    field :promote_tag, non_null(:string)
    field :tags,        list_of(non_null(:string))
    field :steps,       list_of(:test_step), resolve: dataloader(Test)
    field :creator,     :user, resolve: dataloader(User)
    field :repository,  :repository, resolve: dataloader(Repository)

    timestamps()
  end

  object :test_step do
    field :id,          non_null(:id)
    field :status,      non_null(:test_status)
    field :name,        non_null(:string)
    field :description, non_null(:string)
    field :has_logs,    :boolean, resolve: fn
      %{logs: logs}, _, _ -> {:ok, !!logs}
    end

    timestamps()
  end

  object :step_logs do
    field :step, :test_step
    field :logs, list_of(:string)
  end

  connection node_type: :test
  delta :test

  object :test_queries do
    connection field :tests, node_type: :test do
      arg :version_id,    :id
      arg :repository_id, :id

      resolve &Test.list_tests/2
    end

    field :test, :test do
      arg :id, non_null(:id)

      safe_resolve &Test.resolve_test/2
    end

    field :test_logs, :string do
      arg :id,   non_null(:id)
      arg :step, non_null(:id)

      safe_resolve &Test.resolve_logs/2
    end
  end

  object :test_mutations do
    field :create_test, :test do
      middleware Authenticated
      arg :repository_id, :id
      arg :name,          :string
      arg :attributes,    non_null(:test_attributes)

      safe_resolve &Test.create_test/2
    end

    field :update_test, :test do
      middleware Authenticated
      arg :id,         non_null(:id)
      arg :attributes, non_null(:test_attributes)

      safe_resolve &Test.update_test/2
    end

    field :update_step, :test_step do
      middleware Authenticated
      arg :id,         non_null(:id)
      arg :attributes, non_null(:test_step_attributes)

      safe_resolve &Test.update_step/2
    end

    field :publish_logs, :test_step do
      middleware Authenticated
      arg :id,   non_null(:id)
      arg :logs, non_null(:string)

      safe_resolve &Test.publish_logs/2
    end
  end

  object :test_subscriptions do
    field :test_delta, :test_delta do
      arg :repository_id, non_null(:id)
      config fn %{repository_id: id}, _ -> {:ok, topic: "tests:#{id}"} end
    end

    field :test_logs, :step_logs do
      arg :test_id, non_null(:id)
      config fn %{test_id: id}, _ -> {:ok, topic: "test_logs:#{id}"} end
    end
  end
end
