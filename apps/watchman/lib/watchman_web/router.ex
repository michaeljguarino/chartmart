defmodule WatchmanWeb.Router do
  use WatchmanWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug WatchmanWeb.Plugs.Authorized
  end

  get "/health", WatchmanWeb.HealthController, :health

  scope "/v1", WatchmanWeb do
    pipe_through [:api]

    post "/webhook", WebhookController, :webhook
  end

  forward "/graphiql", Absinthe.Plug.GraphiQL,
    schema: Watchman.GraphQl,
    interface: :advanced

  scope "/" do
    pipe_through [:auth]

    forward "/gql", Absinthe.Plug,
      schema: Watchman.GraphQl
  end

  scope "/", WatchmanWeb do
    get "/", PageController, :index
    get "/*path", PageController, :index
  end
end
