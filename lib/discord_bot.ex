defmodule DiscordBot do
  use Application

  def start(_type, _args) do
    children = [DiscordBot.Consumer, DiscordBot.RssReader, DiscordBot.Repo]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
