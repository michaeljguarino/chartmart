defmodule Core.Services.Dns do
  use Core.Services.Base
  import Core.Policies.Dns

  alias Core.Schema.{DnsDomain, DnsRecord, User}
  alias Core.Services.Accounts
  alias Cloudflare.DnsRecord, as: Record
  require Logger

  @ttl 120
  @type error :: {:error, term}
  @type domain_resp :: {:ok, DnsDomain.t} | error
  @type record_resp :: {:ok, DnsRecord.t} | error

  def get_domain(name), do: Core.Repo.get_by(DnsDomain, name: name)

  def records(%DnsDomain{id: id}) do
    DnsRecord.for_domain(id)
    |> Core.Repo.all()
  end

  @spec nonempty?(DnsDomain.t) :: boolean
  def nonempty?(%DnsDomain{id: id}) do
    DnsRecord.for_domain(id)
    |> Core.Repo.exists?()
  end

  @spec authorized(binary, User.t) :: domain_resp
  def authorized(id, %User{} = user) do
    Core.Repo.get(DnsDomain, id)
    |> allow(user, :access)
  end

  @spec create_domain(map, User.t) :: domain_resp
  def create_domain(attrs, %User{id: id, account_id: aid} = user) do
    start_transaction()
    |> add_operation(:dns, fn _ ->
      %DnsDomain{creator_id: id, account_id: aid}
      |> DnsDomain.changeset(attrs)
      |> allow(user, :create)
      |> when_ok(:insert)
    end)
    |> add_operation(:validate, fn %{dns: %{account_id: aid} = dns} ->
      case Core.Repo.preload(dns, [access_policy: :bindings]) do
        %{access_policy: %{bindings: bindings}} -> Accounts.validate_bindings(aid, bindings)
        _ -> {:ok, dns}
      end
    end)
    |> execute(extract: :dns)
  end

  @spec update_domain(map, binary, User.t) :: domain_resp
  def update_domain(attrs, id, %User{} = user) do
    start_transaction()
    |> add_operation(:dns, fn _ ->
      Core.Repo.get(DnsDomain, id)
      |> Core.Repo.preload(access_policy: :bindings)
      |> allow(user, :edit)
      |> when_ok(&DnsDomain.update_changeset(&1, attrs))
      |> when_ok(:update)
    end)
    |> add_operation(:validate, fn %{dns: %{account_id: aid} = dns} ->
      case Core.Repo.preload(dns, [access_policy: :bindings]) do
        %{access_policy: %{bindings: bindings}} -> Accounts.validate_bindings(aid, bindings)
        _ -> {:ok, dns}
      end
    end)
    |> execute(extract: :dns)
  end

  def delete_domain(id, %User{} = user) do
    Core.Repo.get(DnsDomain, id)
    |> Core.Repo.preload(access_policy: :bindings)
    |> allow(user, :delete)
    |> when_ok(:delete)
  end

  @spec provision_domain(binary, User.t) :: domain_resp
  def provision_domain(name, %User{} = user) do
    case get_domain(name) do
      %DnsDomain{} = domain -> domain_accessible(domain, user)
      _ -> create_domain(%{name: name}, user)
    end
  end

  def domain_accessible(%DnsDomain{} = domain, %User{} = user) do
    with {:ok, _} <- allow(%DnsRecord{domain: domain}, user, :create),
      do: {:ok, domain}
  end

  @spec create_record(map, binary, atom, User.t) :: record_resp
  def create_record(%{name: name, type: t} = attrs, cluster, provider, %User{} = user) do
    Logger.info "Attempting to create record #{t}:#{name}"
    start_transaction()
    |> add_operation(:domain, fn _ ->
      domain_name(name)
      |> get_domain()
      |> Core.Repo.preload([access_policy: :bindings])
      |> case do
        %DnsDomain{} = d -> {:ok, d}
        nil -> {:error, "domain not found"}
      end
    end)
    |> add_operation(:fetch, fn _ ->
      {:ok, Core.Repo.get_by(DnsRecord, name: name, type: t)}
    end)
    |> add_operation(:record, fn
      %{fetch: nil, domain: domain} ->
        %DnsRecord{creator_id: user.id, domain_id: domain.id}
        |> DnsRecord.changeset(Map.merge(attrs, %{cluster: cluster, provider: provider}))
        |> DnsRecord.dns_valid(domain.name)
        |> allow(user, :create)
        |> when_ok(:insert)
      %{fetch: %DnsRecord{cluster: ^cluster, provider: ^provider} = record} ->
        DnsRecord.changeset(record, attrs)
        |> allow(user, :edit)
        |> when_ok(:update)
      %{fetch: %DnsRecord{cluster: c, provider: p}} ->
        {:error, "This record already is in use by #{p}/#{c}"}
    end)
    |> add_operation(:external, fn
      %{fetch: nil, record: record} ->
        cloudflare_record(record)
        |> Record.create(params: [zone_id: zone_id()])
        |> extract_id()
      %{record: %{external_id: id} = record} ->
        Record.update(id, cloudflare_record(record), params: [zone_id: zone_id()])
        |> extract_id()
    end)
    |> add_operation(:hydrate, fn %{record: r, external: id} ->
      DnsRecord.changeset(r, %{external_id: id})
      |> Core.Repo.update()
    end)
    |> execute(extract: :hydrate)
  end

  @spec delete_record(binary, atom, User.t) :: record_resp
  def delete_record(name, type, %User{} = user) do
    Logger.info "Attempting to delete record #{type}:#{name}"
    start_transaction()
    |> add_operation(:record, fn _ ->
      Core.Repo.get_by!(DnsRecord, name: name, type: type)
      |> allow(user, :delete)
      |> when_ok(:delete)
    end)
    |> add_operation(:external, fn %{record: r} ->
      Record.delete(r.external_id, params: [zone_id: zone_id()])
      |> extract_id()
    end)
    |> execute(extract: :record)
  end

  defp cloudflare_record(%DnsRecord{name: name, type: t, records: r}) do
    %{
      name: name,
      type: String.upcase("#{t}"),
      content: Enum.join(r, "\n"),
      ttl: @ttl
    }
  end

  defp extract_id({:ok, %{body: %{"result" => %{"id" => id}}}}), do: {:ok, id}
  defp extract_id(error) do
    Logger.error "Cloudflare failed with #{inspect(error)}"
    {:error, "cloudflare failure"}
  end

  defp domain_name(name) do
    String.trim(name, ".")
    |> String.split(".")
    |> Enum.reverse()
    |> case do
      [tld, onplural, domain | _] ->
        Enum.join([domain, onplural, tld], ".")
      _ -> "__bogus__"
    end
  end

  defp zone_id(), do: Core.conf(:cloudflare_zone)
end
