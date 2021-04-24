defmodule DiscordBot.Consumer do
  require Logger
  use Nostrum.Consumer
  alias Nostrum.{Api, Struct.Interaction}
  alias DiscordBot.{Schema.Feed, Repo}
  import Ecto.Query

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  # TODO: HANDLE CHANNEL DELETION EVENT
  # Delete all feed subscriptions with that channel
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "ping!" ->
        IO.inspect(msg.channel_id)
        Api.create_message(msg.channel_id, "Test!")

      _ ->
        :ignore
    end
  end

  # TODO: theoretically we should be waiting for the GUILD_AVAILABLE
  # event before pushing feeds
  def handle_event({:READY, _info_map, _ws_state}) do
    Logger.info("READY!")
    Process.send(DiscordBot.RssReader, :pull_rss, [])
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           data: %{name: "sub", options: [%{value: url}]},
           channel_id: channel
         } = interaction, _ws_state}
      ) do
    response = %{
      # ChannelMessageWithSource
      type: 4,
      data: %{
        content: "url added: #{url}"
      }
    }

    %Feed{url: url, channel: channel}
    |> Repo.insert!()

    Api.create_interaction_response(interaction, response)
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           data: %{name: "feeds"},
           channel_id: channel
         } = interaction, _ws_state}
      ) do
    content =
      Repo.all(
        from(f in Feed,
          where: f.channel == ^channel
        )
      )
      |> Enum.map(fn %Feed{url: url} -> "* #{url}" end)
      |> Enum.join("\n")
      |> case do
        "" -> "There are no feeds!"
        feeds -> feeds
      end

    response = %{
      # ChannelMessageWithSource
      type: 4,
      data: %{
        content: content
      }
    }

    Api.create_interaction_response(interaction, response)
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           data: %{name: "unsub", options: [%{value: url}]},
           channel_id: channel
         } = interaction, _ws_state}
      ) do
    Repo.delete_all(
      from(f in Feed,
        where: f.url == ^url and f.channel == ^channel
      )
    )

    response = %{
      # ChannelMessageWithSource
      type: 4,
      data: %{
        content: "Deleted #{url}!"
      }
    }

    Api.create_interaction_response(interaction, response)
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(event) when is_tuple(event) do
    if tuple_size(event) > 0 and elem(event, 0) |> is_atom do
      Logger.warn("Unused event #{event |> elem(0)}")
    end

    :noop
  end

  def handle_event(_event) do
    :noop
  end
end
