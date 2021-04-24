defmodule DiscordBot.Repo.Migrations.AddFeedTable do
  use Ecto.Migration

  def change do
    create table("feed") do
      add(:url, :string)
      add(:channel, :integer)
    end
  end
end
