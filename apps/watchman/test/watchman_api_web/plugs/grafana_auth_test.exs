defmodule WatchmanWeb.Plugs.GrafanaAuthTest do
  use WatchmanWeb.ConnCase, async: true
  use Mimic

  alias WatchmanWeb.Plugs.GrafanaAuth

  setup :set_mimic_global

  describe "call/2" do
    test "It can authorize against an incoming cookie and rewrite to basic auth", %{conn: conn} do
      expect(Kazan, :run, fn
        %Kazan.Request{method: "get", path: "/api/v1/namespaces/forge/secrets/grafana-credentials"} ->
          {:ok, %Kazan.Apis.Core.V1.Secret{data: %{
            "admin-user" => Base.encode64("admin"),
            "admin-password" => Base.encode64("password")}
          }}
      end)
      send Watchman.Grafana.Token, :refetch

      secret = Watchman.conf(:webhook_secret)
      result = GrafanaAuth.call(%{conn | req_cookies: [{"grafana_token", Base.encode64(secret, padding: false)}]}, [])

      refute result.status == 401
      ["Basic " <> basic] = get_req_header(result, "authorization")
      ["admin", "password"] = Base.decode64!(basic) |> String.split(":")
    end
  end
end