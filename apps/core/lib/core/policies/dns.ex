defmodule Core.Policies.Dns do
  use Piazza.Policy
  alias Core.Services.{Rbac, Dns}
  alias Core.Schema.{User, DnsDomain, DnsRecord, DnsAccessPolicy}

  @policy_msg "you cannot edit this dns domain, are you on its access policy?"

  def can?(%User{id: uid}, %DnsDomain{creator_id: uid}, :edit),
    do: :pass
  def can?(user, %DnsDomain{access_policy: %DnsAccessPolicy{} = policy}, :edit) do
    Rbac.evaluate_policy(user, policy)
    |> error(@policy_msg)
  end
  def can?(_, %DnsDomain{}, :edit), do: {:error, :forbidden}

  def can?(user, %DnsDomain{} = domain, :delete) do
    case Dns.nonempty?(domain) do
      false -> can?(user, domain, :edit)
      true -> {:error, "domain is not empty"}
    end
  end

  def can?(%User{account_id: aid}, %DnsDomain{account_id: aid}, _),
    do: :pass

  def can?(%User{id: id}, %DnsRecord{creator_id: id}, :delete), do: :pass
  def can?(%User{account_id: id, id: uid} = user, %DnsRecord{} = record, action) when action != :delete do
    case Core.Repo.preload(record, [domain: [access_policy: :bindings]]) do
      %{domain: %DnsDomain{creator_id: ^uid}} -> :pass
      %{domain: %DnsDomain{account_id: ^id, access_policy: nil}} -> :pass
      %{domain: %DnsDomain{account_id: ^id, access_policy: policy}} ->
        Rbac.evaluate_policy(user, policy) |> error(@policy_msg)
      _ -> {:error, "your account does not own this dns domain, please try another"}
    end
  end

  def can?(user, %Ecto.Changeset{} = cs, action),
    do: can?(user, apply_changes(cs), action)
  def can?(_, _, _), do: {:error, :forbidden}
end
