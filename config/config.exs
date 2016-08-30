# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :rbmq, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:rbmq, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# config :rbmq,
#   host: {:system, "HOST", "localhost"},
#   port: "5672",
#   username: "guest",
#   password: "guest",
#   prefetch_count: "10",
#   amqp_exchange: "rbmq_exchange",
#   foo: {:system, "BAR"}

config :rbmq, amqp_exchange: "rbmq_exchange"
config :rbmq, prefetch_count: "10"
config :rbmq, amqp_params: [
  host: "localhost",
  port: "5672",
  username: "guest",
  password: "guest",
]

# Disable logger if you don't want to see verbose messages
# config :logger, level: :info
