import Config
import System, only: [get_env: 1]

host = get_env("HOST")

config :api, ApiWeb.Endpoint,
  url: [host: host, port: 8080],
  check_origin: ["//#{host}", "//plural-api"]

config :rtc, RtcWeb.Endpoint,
  url: [host: host, port: 8080],
  check_origin: ["//#{host}", "//plural-rtc"]

config :core, hostname: host
config :email, host: "https://#{host}"
config :core, host: "https://#{host}"

config :arc,
  storage: Arc.Storage.GCS,
  bucket: get_env("BUCKET")

config :core, Core.Guardian,
  issuer: "plural",
  secret_key: get_env("JWT_SECRET")



if get_env("POSTGRES_URL") do
  config :core, Core.Repo,
    url: get_env("POSTGRES_URL"),
    ssl: String.to_existing_atom(get_env("DBSSL") || "true"),
    pool_size: 5
else
  config :core, Core.Repo,
    database: "plural",
    username: "plural",
    password: get_env("POSTGRES_PASSWORD"),
    hostname: get_env("DBHOST") || "plural-postgresql",
    ssl: String.to_existing_atom(get_env("DBSSL") || "false"),
    pool_size: 5
end

config :cloudflare,
  auth_token: get_env("CLOUDFLARE_AUTH_TOKEN")

config :core, Core.Influx,
  database: "plural",
  host: "influxdb.influx",
  auth: [method: :basic, username: "admin", password: get_env("INFLUX_PAASSWORD")],
  port: 8086

config :core, :jwt,
  pk: get_env("JWT_PRIVATE_KEY"),
  cert: get_env("JWT_CERT"),
  iss: get_env("JWT_ISS"),
  aud: get_env("JWT_AUD")

config :core, Core.Conduit.Broker,
  adapter: ConduitAMQP,
  url: "amqp://#{get_env("RABBIT_USERNAME")}:#{get_env("RABBIT_PASSWORD")}@rabbitmq.#{get_env("RABBIT_NAMESPACE")}"

config :rtc, Rtc.Conduit.Broker,
  adapter: ConduitAMQP,
  url: "amqp://#{get_env("RABBIT_USERNAME")}:#{get_env("RABBIT_PASSWORD")}@rabbitmq.#{get_env("RABBIT_NAMESPACE")}"

config :worker, Worker.Conduit.Broker,
  adapter: ConduitAMQP,
  url: "amqp://#{get_env("RABBIT_USERNAME")}:#{get_env("RABBIT_PASSWORD")}@rabbitmq.#{get_env("RABBIT_NAMESPACE")}"

config :piazza_core, aes_key: get_env("AES_KEY")

config :core, Core.Clients.Zoom,
  client_id: get_env("ZOOM_CLIENT_ID"),
  client_secret: get_env("ZOOM_CLIENT_SECRET")

config :core,
  chartmuseum: "http://chartmuseum:8080",
  plural_cmd: "/usr/local/bin/plural",
  stripe_connect_id: get_env("STRIPE_CONNECT_ID"),
  stripe_publishable_key: get_env("STRIPE_PUBLISHABLE_KEY"),
  hydra_public_url: get_env("HYDRA_URL") || "https://oidc.plural.sh",
  git_commit: get_env("GIT_COMMIT"),
  cloudflare_zone: get_env("CLOUDFLARE_ZONE"),
  acme_key_id: get_env("ACME_KEY_ID"),
  acme_secret: get_env("ACME_SECRET"),
  zerossl_access_key: get_env("ZEROSSL_ACCESS_KEY"),
  docker_metrics_table: ~s("permanent"."downsampled_docker_pulls"),
  workos_webhook: get_env("WORKOS_WEBHOOK_SECRET"),
  gcp_identity: get_env("GCP_USER_EMAIL") || "mjg@plural.sh",
  openai_token: get_env("OPENAI_BEARER_TOKEN"),
  enforce_pricing: get_env("ENFORCE_PRICING"),
  stripe_webhook_secret: get_env("STRIPE_WEBHOOK_SECRET"),
  github_demo_token: get_env("GITHUB_DEMO_TOKEN"),
  console_token: get_env("CONSOLE_SA_TOKEN"),
  dedicated_console_token: get_env("CONSOLE_DEDICATED_SA_TOKEN"),
  dedicated_project: get_env("CONSOLE_DEDICATED_PROJECT"),
  mgmt_cluster: get_env("MGMT_CLUSTER_ID"),
  console_url: get_env("CONSOLE_URL"),
  mgmt_repo: get_env("CONSOLE_MGMT_REPO"),
  stack_id: get_env("CONSOLE_CLOUD_STACK_ID"),
  cloud_domain: get_env("CONSOLE_CLOUD_DOMAIN") || "cloud.plural.sh"


if get_env("VAULT_HOST") do
  config :core, vault: get_env("VAULT_HOST")
end

if get_env("SYSBOX_WHITELIST") do
  config :core, :sysbox_emails, String.split(get_env("SYSBOX_WHITELIST"), ",")
end

if get_env("INTERCOM_SALT") do
  config :core, intercom_salt: get_env("INTERCOM_SALT")
end

config :workos,
  client_id: get_env("WORKOS_CLIENT_ID"),
  api_key: get_env("WORKOS_API_KEY")


provider = case get_env("PROVIDER") || "google" do
  "google" -> :gcp
  "gcp" -> :gcp
  "aws" -> :aws
  "azure" -> :azure
  "equinix" -> :equinix
  "kind" -> :kind
  "generic" -> :generic
  _ -> :custom
end

if provider != :gcp do
  config :goth, disabled: true
  config :arc, storage: Arc.Storage.S3
end

if org_id = get_env("GCP_ORG_ID") do
  config :core,
    gcp_organization: org_id
end

if get_env("GCP_CREDENTIALS") do
  config :goth,
    json: {:system, "GCP_CREDENTIALS"},
    project_id: get_env("GCP_PROJECT") || "pluralsh",
    disabled: false
end

config :core,
  registry: get_env("DKR_DNS")

config :openai,
  token: get_env("OPENAI_BEARER_TOKEN")


config :tzdata, :autoupdate, :disabled
