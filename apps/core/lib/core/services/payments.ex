defmodule Core.Services.Payments do
  use Core.Services.Base
  import Core.Policies.Payments

  alias Core.Services.{Repositories}
  alias Core.Schema.{
    Publisher,
    User,
    Repository,
    Plan,
    Subscription,
    Installation
  }

  def get_plan!(id), do: Core.Repo.get!(Plan, id)

  def get_subscription!(id), do: Core.Repo.get!(Subscription, id)

  def get_subscription(repository_id, user_id) do
    with %Installation{id: id} <- Repositories.get_installation(user_id, repository_id),
      do: Core.Repo.get_by(Subscription, installation_id: id)
  end

  def create_publisher_account(%Publisher{} = publisher, code) do
    with {:ok, %{stripe_user_id: account_id}} <- Stripe.Connect.OAuth.token(code) do
      publisher
      |> Publisher.stripe_changeset(%{account_id: account_id})
      |> Core.Repo.update()
    end
  end

  def register_customer(%User{email: email} = user, source_token) do
    with {:ok, %{id: id}} <- Stripe.Customer.create(%{email: email, source: source_token}) do
      user
      |> User.stripe_changeset(%{customer_id: id})
      |> Core.Repo.update()
    end
  end

  def create_plan(attrs, %Repository{id: id} = repo, %User{} = user) do
    %{publisher: publisher} = Core.Repo.preload(repo, [:publisher])

    start_transaction()
    |> add_operation(:db, fn _ ->
      %Plan{repository_id: id}
      |> Plan.changeset(attrs)
      |> allow(user, :create)
      |> when_ok(:insert)
    end)
    |> add_operation(:stripe, fn %{db: plan} ->
      build_plan_ops([base: %{
        amount:   plan.cost,
        currency: "USD",
        interval: stripe_interval(plan.period),
        product: %{name: plan.name}
      }], plan.line_items)
      |> Enum.reduce(short_circuit(), fn {name, op}, circuit ->
        short(circuit, name, fn ->
          Stripe.Plan.create(op, connect_account: publisher.account_id)
        end)
      end)
      |> execute()
    end)
    |> add_operation(:finalized, fn %{db: db, stripe: %{base: %{id: id}} = stripe} ->
      rest = Map.delete(stripe, :base)

      db
      |> Plan.changeset(Map.merge(%{external_id: id}, restitch_line_items(db, rest)))
      |> Core.Repo.update()
    end)
    |> execute(extract: :finalized)
  end
  def create_plan(attrs, repo_id, user),
    do: create_plan(attrs, Repositories.get_repository!(repo_id), user)

  defp build_plan_ops(ops, %{items: items}), do: build_plan_ops(ops, items)
  defp build_plan_ops(ops, items) when is_list(items) do
    Enum.map(items, fn %{cost: cost, period: period, name: name, dimension: dim} ->
      {dim, %{amount: cost, currency: "USD", interval: stripe_interval(period), product: %{name: name}}}
    end)
    |> Enum.concat(ops)
  end
  defp build_plan_ops(ops, _), do: ops

  defp restitch_line_items(%{line_items: %{items: items}}, rest) do
    %{line_items: %{
      items: Enum.map(items, fn %{dimension: dimension} = item ->
               Piazza.Ecto.Schema.mapify(item)
               |> Map.put(:external_id, rest[dimension].id)
             end)
      }
    }
  end
  defp restitch_line_items(_, _), do: %{}

  def create_subscription(attrs \\ %{}, plan, inst, user)
  def create_subscription(_, _, _, %User{customer_id: nil}), do: {:error, "No payment method"}
  def create_subscription(attrs, %Plan{} = plan, %Installation{} = installation, %User{} = user) do
    %{repository: %{publisher: %{account_id: account_id}}} = plan =
      Core.Repo.preload(plan, [repository: :publisher])

    start_transaction()
    |> add_operation(:db, fn _ ->
      %Subscription{plan_id: plan.id, plan: plan}
      |> Subscription.changeset(Map.merge(attrs, %{installation_id: installation.id}))
      |> allow(user, :create)
      |> when_ok(:insert)
    end)
    |> add_operation(:customer, fn _ ->
      with {:ok, %{id: id}} <- Stripe.Token.create(%{
        customer: user.customer_id
      }, connect_account: account_id) do
        Stripe.Customer.create(%{
          email: user.email,
          source: id
        }, connect_account: account_id)
      end
    end)
    |> add_operation(:stripe, fn %{customer: customer, db: db} ->
      Stripe.Subscription.create(%{
        customer: customer.id,
        application_fee_percent: conf(:application_fee),
        items: [%{plan: plan.external_id} | sub_line_items(plan, db)]
      }, connect_account: account_id)
    end)
    |> add_operation(:finalized, fn
      %{
        stripe: %{id: sub_id, items: %{data: [%{id: id} | rest]}},
        customer: %{id: cus_id},
        db: subscription
      } ->
      subscription
      |> Subscription.stripe_changeset(%{
        external_id: sub_id,
        customer_id: cus_id,
        line_items: %{
          item_id: id,
          items: rebuild_line_items(subscription, plan, rest)
        }
      })
      |> Core.Repo.update()
    end)
    |> execute(extract: :finalized)
  end
  def create_subscription(attrs, plan_id, inst_id, %User{} = user) do
    plan = get_plan!(plan_id)
    inst = Repositories.get_installation!(inst_id)

    create_subscription(attrs, plan, inst, user)
  end

  def update_line_item(
    %{dimension: dim, quantity: quantity},
    %Subscription{line_items: %{items: items}} = sub,
    %User{} = user
  ) do
    %{installation: %{repository: %{publisher: %{account_id: account_id}}}} = sub =
      Core.Repo.preload(sub, [:plan, installation: [repository: :publisher]])

    start_transaction()
    |> add_operation(:db, fn _ ->
      sub
      |> Subscription.changeset(%{line_items: %{
        items: rebuild_subscription_items(items, dim, quantity)
      }})
      |> allow(user, :edit)
      |> when_ok(:update)
    end)
    |> add_operation(:stripe, fn %{db: %{line_items: %{items: items}}} ->
      with %{external_id: ext_id, quantity: quantity} <- Enum.find(items, & &1.dimension == dim) do
        Stripe.SubscriptionItem.update(ext_id, %{quantity: quantity}, connect_account: account_id)
      else
        _ -> {:error, :not_found}
      end
    end)
    |> execute(extract: :db)
  end
  def update_line_item(attrs, subscription_id, user),
    do: update_line_item(attrs, get_subscription!(subscription_id), user)

  def update_plan(%Plan{id: id, external_id: ext_id} = plan, %Subscription{} = sub, %User{} = user) do
    %{installation: %{repository: %{publisher: %{account_id: account_id}}}} = sub =
      Core.Repo.preload(sub, [:plan, installation: [repository: :publisher]])

    start_transaction()
    |> add_operation(:db, fn _ ->
      sub
      |> Subscription.changeset(%{
        plan_id: id,
        line_items: %{items: migrate_line_items(plan, sub)}
      })
      |> allow(user, :edit)
      |> when_ok(:update)
      |> when_ok(&Core.Repo.preload(&1, [:plan], force: true))
    end)
    |> add_operation(:stripe, fn %{db: updated} ->
      Stripe.Subscription.update(sub.external_id, %{
        items: old_items(sub) ++ [%{plan: ext_id}] ++ sub_line_items(updated.plan, updated)
      }, connect_account: account_id)
    end)
    |> add_operation(:finalized, fn
      %{
        stripe: %{id: sub_id, items: %{data: [%{id: id} | rest]}},
        db: subscription
      } ->
      subscription
      |> Subscription.stripe_changeset(%{
        external_id: sub_id,
        line_items: %{
          item_id: id,
          items: rebuild_line_items(subscription, subscription.plan, rest)
        }
      })
      |> Core.Repo.update()
    end)
    |> execute(extract: :finalized)
  end
  def update_plan(plan_id, sub_id, user) do
    get_plan!(plan_id) |> update_plan(get_subscription!(sub_id), user)
  end

  defp old_items(%Subscription{plan: %Plan{external_id: plan_id, line_items: %{items: items}}}) do
    line_items = Enum.map(items, fn %{external_id: id} -> %{plan: id, deleted: true} end)
    [%{plan: plan_id, deleted: true} | line_items]
  end

  defp sub_line_items(
    %Plan{line_items: %{items: line_items}},
    %Subscription{line_items: %{items: items}}
  ) when is_list(line_items) and is_list(items) do
    by_dimension = Enum.into(items, %{}, & {&1.dimension, &1})

    Enum.map(line_items, fn %{external_id: id, dimension: dim} ->
      %{plan: id, quantity: fetch_quantity(by_dimension[dim])}
    end)
  end
  defp sub_line_items(_, _), do: []

  defp migrate_line_items(%Plan{line_items: %{items: items, included: included}}, subscription) do
    by_dimension = Enum.into(included, %{}, & {&1.dimension, &1})

    Enum.map(items, fn %{dimension: dimension} ->
      current  = Subscription.dimension(subscription, dimension)
      included = fetch_quantity(by_dimension[dimension])
      %{dimension: dimension, quantity: max(current - included, 0)}
    end)
  end

  defp rebuild_line_items(
    %{line_items: %{items: items}},
    %{line_items: %{items: line_items}},
    stripe_items
  ) when is_list(line_items) do
    by_stripe_id = Enum.into(stripe_items, %{}, & {&1.plan.id, &1})
    by_dimension = Enum.into(items, %{}, & {&1.dimension, &1})

    Enum.map(line_items, fn %{external_id: id, dimension: dim} ->
      %{
        dimension: dim,
        quantity: fetch_quantity(by_dimension[dim]),
        external_id: by_stripe_id[id].id
      }
    end)
  end
  defp rebuild_line_items(_, _, _), do: []

  defp rebuild_subscription_items(items, dimension, quantity) do
    Enum.map(items, fn
      %{dimension: ^dimension} = item -> %{Piazza.Ecto.Schema.mapify(item) | quantity: quantity}
      item -> Piazza.Ecto.Schema.mapify(item)
    end)
    |> Enum.map(&Map.take(&1, [:dimension, :quantity, :external_id]))
  end

  defp fetch_quantity(%{quantity: quantity}) when is_integer(quantity), do: quantity
  defp fetch_quantity(_), do: 0

  defp stripe_interval(:monthly), do: "month"
  defp stripe_interval(:yearly), do: "year"
end