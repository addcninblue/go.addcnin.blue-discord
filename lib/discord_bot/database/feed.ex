defmodule DiscordBot.Schema.Feed do
  use Ecto.Schema

  schema "feed" do
    field(:url, :string)
    field(:channel, :integer)
  end
end
