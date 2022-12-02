defmodule Core.Storage do
  use Waffle.Definition
  use Waffle.Ecto.Definition
  alias Core.Schema.{
    User,
    Publisher,
    Repository,
    Terraform,
    Integration,
    Artifact,
    Crd,
    Version,
    File,
    Publisher,
    Account,
    TestStep
  }

  @acl :public_read
  @versions [:original]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  def validate({_, %User{trusted_icon: true}}), do: true
  def validate({file, %User{}}) do
    file_extension = file.file_name |> Path.extname |> String.downcase
    Enum.member?(@extension_whitelist, file_extension)
  end
  def validate(_), do: true

  def asset_host() do
    %{host: host, scheme: scheme} = ExAws.Config.new(:s3)
    "#{scheme}#{bucket()}.#{host}"
  end

  # def transform(:thumb, _) do
  #   {:convert, "-thumbnail 100x100^ -gravity center -extent 100x100 -format png", :png}
  # end

  def storage_dir(_, {_file, %Terraform{package_id: pkg_id}}), do: "terraform/#{pkg_id}"
  def storage_dir(_, {_file, %Version{package_id: pkg_id, terraform_id: id}}) when not is_nil(id),
    do: "terraform/#{pkg_id}"
  def storage_dir(_, {_file, %User{avatar_id: avatar_id}}), do: "uploads/avatars/#{avatar_id}"
  def storage_dir(_, {_file, %Publisher{avatar_id: avatar_id}}), do: "uploads/pubs/#{avatar_id}"
  def storage_dir(_, {_file, %Repository{icon_id: icon_id}}), do: "uploads/repos/#{icon_id}"
  def storage_dir(_, {_file, %Integration{icon_id: icon_id}}), do: "uploads/integrations/#{icon_id}"
  def storage_dir(_, {_file, %Artifact{blob_id: blob_id}}), do: "uploads/artifacts/#{blob_id}"
  def storage_dir(_, {_file, %Crd{blob_id: blob_id}}), do: "uploads/crds/#{blob_id}"
  def storage_dir(_, {_file, %File{blob_id: blob_id}}), do: "uploads/files/#{blob_id}"
  def storage_dir(_, {_file, %Account{icon_id: icon_id}}), do: "uploads/accounts/#{icon_id}"
  def storage_dir(_, {_file, %TestStep{id: id}}), do: "uploads/test_logs/#{id}"

  def default_url(_), do: nil
end
