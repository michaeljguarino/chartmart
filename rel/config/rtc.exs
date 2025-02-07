import Config
import System, only: [get_env: 1]

config :rtc, RtcWeb.Endpoint,
  url: [host: get_env("HOST"), port: 8080],
  check_origin: ["//#{get_env("HOST")}", "//plural-rtc"],
  secret_key_base: get_env("SECRET_KEY_BASE"),
  server: true

config :core, broker: Rtc.Conduit.Broker
config :core, start_broker: false
config :rtc, start_broker: true

config :libcluster,
  topologies: [
    rtc: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        mode: :ip,
        kubernetes_node_basename: "rtc",
        kubernetes_selector: "app=plural-rtc",
        kubernetes_namespace: get_env("NAMESPACE"),
        polling_interval: 10_000
      ]
    ]
  ]
