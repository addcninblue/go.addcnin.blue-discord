defmodule DiscordBot.RssReader do
  alias DiscordBot.{Schema.Feed, Repo}
  alias Nostrum.Api
  import Ecto.Query
  require Logger
  use GenServer

  @timeout 5 * 60 * 1000

  def start_link(_init) do
    GenServer.start(DiscordBot.RssReader, nil, name: __MODULE__)
  end

  @impl true
  def init(_init) do
    {:ok, nil}
  end

  @impl true
  def handle_info(:pull_rss, state) do
    pull_rss(state)
    Process.send_after(self(), :pull_rss, @timeout)
    {:noreply, state}
  end

  def pull_rss(_state) do
    links_grouped = Repo.all(from(f in Feed)) |> Enum.group_by(& &1.channel)

    for {channel, links} <- links_grouped do
      for link <- links do
        {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get(link.url)
        {:ok, feed, _} = FeederEx.parse(body)

        entries =
          feed.entries
          |> Enum.filter(fn entry ->
            # (Ab)using Elixir's `with` special form to try many different
            # parse methods until one succeeds. This means the "happy path"
            # is failure and the "exception path" is success.
            with true <- String.valid?(entry.updated),
                 {:error, _} <- Timex.parse(entry.updated, "{RFC822}"),
                 {:error, _} <- Timex.parse(entry.updated, "{RFC1123}"),
                 {:error, _} <- Timex.parse(entry.updated, "{RFC3339}") do
              Logger.warn("Unable to parse timestamp #{entry.updated} for link #{link.url}")
              false
            else
              # String is not valid
              false ->
                false

              {:ok, time} ->
                subtracted =
                  Timex.subtract(
                    Timex.now(),
                    Timex.Duration.from_milliseconds(@timeout + 1 * 1000)
                  )

                Timex.before?(subtracted, time)
            end
          end)
          |> Enum.filter(&(!is_nil(&1.title)))
          |> Enum.filter(&(!is_nil(&1.link)))

        for entry <- entries do
          title =
            case entry.title do
              nil -> ""
              title -> title
            end

          link =
            case entry.link do
              nil -> ""
              link -> link
            end

          summary =
            case entry.summary do
              nil -> ""
              summary -> summary
            end

          Api.create_message(channel, "**#{title}**\n\n#{link}")
        end
      end
    end
  end
end
