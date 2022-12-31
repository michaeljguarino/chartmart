defmodule ApiWeb.FallbackController do
  use Phoenix.Controller
  require Logger

  def call(conn, {:error, error}) do
    {error, msg} = error(error)

    conn
    |> put_status(error)
    |> json(%{message: msg})
  end

  def call(conn, error) do
    Logger.error "Found error: #{inspect(error)}"
    call(conn, {:error, :unknown})
  end

  def error(:invalid_password), do: {401, "Invalid Password"}
  def error(:not_found), do: {404, "Not Found"}
  def error(:forbidden), do: {403, "You're not allowed to access that resource"}
  def error(%Ecto.Changeset{} = cs), do: {422, format_changeset(cs)}
  def error(val) when is_atom(val), do: {422, val}
  def error(val) when is_binary(val), do: {422, val}
  def error(_), do: {422, "unknown error"}

  defp format_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
