defmodule GraphQl.Schema.OAuth do
  use GraphQl.Schema.Base
  alias GraphQl.Resolvers.{OAuth, User, Repository}

  enum :oauth_provider do
    value :github
    value :google
    value :gitlab
  end

  object :oauth_response do
    field :redirect_to, non_null(:string)
  end

  object :oauth_info do
    field :provider, non_null(:oauth_provider)
    field :authorize_url, non_null(:string)
  end

  object :ouath_configuration do
    field :issuer,                 :string
    field :authorization_endpoint, :string
    field :token_endpoint,         :string
    field :jwks_uri,               :string
    field :userinfo_endpoint,      :string
  end

  object :consent_request do
    field :requested_scope, list_of(:string)
    field :skip,            :boolean
  end

  object :login_request do
    field :requested_scope, list_of(:string)
    field :subject,         :string
  end

  object :oidc_login do
    field :id,        non_null(:id)
    field :ip,        :string
    field :country,   :string
    field :city,      :string
    field :latitude,  :string
    field :longitude, :string

    field :user,       :user, resolve: dataloader(User)
    field :owner,      :user, resolve: dataloader(User)
    field :repository, :repository, resolve: dataloader(Repository)

    timestamps()
  end

  object :oidc_step_response do
    field :repository, :repository
    field :login,      :login_request
    field :consent,    :consent_request
  end

  connection node_type: :oidc_login

  object :oauth_queries do
    field :oauth_login, :repository do
      arg :challenge, non_null(:string)

      resolve &OAuth.resolve_login/2
    end

    field :oauth_consent, :repository do
      arg :challenge, non_null(:string)

      resolve &OAuth.resolve_consent/2
    end

    field :oidc_login, :oidc_step_response do
      arg :challenge, non_null(:string)

      resolve &OAuth.resolve_oidc_login/2
    end

    field :oidc_consent, :oidc_step_response do
      arg :challenge, non_null(:string)

      resolve &OAuth.resolve_oidc_consent/2
    end

    field :oauth_urls, list_of(:oauth_info) do
      arg :host, :string

      resolve &OAuth.list_urls/2
    end

    connection field :oidc_logins, node_type: :oidc_login do
      middleware Authenticated

      safe_resolve &OAuth.list_logins/2
    end

    field :login_metrics, list_of(:geo_metric) do
      middleware Authenticated

      resolve &OAuth.login_metrics/2
    end
  end

  object :oauth_mutations do
    field :accept_login, :oauth_response do
      middleware Authenticated
      arg :challenge, non_null(:string)

      safe_resolve &OAuth.accept_login/2
    end

    field :oauth_consent, :oauth_response do
      middleware Authenticated
      arg :challenge, non_null(:string)
      arg :scopes, list_of(:string)

      safe_resolve &OAuth.accept_consent/2
    end

    field :oauth_callback, :user do
      middleware GraphQl.Middleware.AllowJwt
      arg :provider, non_null(:oauth_provider)
      arg :host, :string
      arg :code, non_null(:string)
      arg :device_token, :string

      safe_resolve &OAuth.resolve_callback/2
    end

    field :sso_callback, :user do
      middleware GraphQl.Middleware.AllowJwt
      arg :code, non_null(:string)
      arg :device_token, :string

      safe_resolve &OAuth.sso_callback/2
    end
  end
end
