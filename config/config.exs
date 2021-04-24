import Config

config :nostrum,
  # The number of shards you want to run your bot under, or :auto.
  num_shards: :auto

config :discord_bot,
  ecto_repos: [DiscordBot.Repo]

config :discord_bot, DiscordBot.Repo, database: "priv/database/database.db"

import_config("secrets.exs")
