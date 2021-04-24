defmodule DiscordBot.RssReader do
  use GenServer
  alias Nostrum.Api

  @links Application.fetch_env!(:discord_bot, :links)
  @timeout 5 * 60 * 1000

  def start_link(_init) do
    GenServer.start(DiscordBot.RssReader, nil, name: __MODULE__)
  end

  @impl true
  def init(_init) do
    pull_rss(nil)
    {:ok, nil}
  end

  @impl true
  def handle_info(:pull_rss, state) do
    pull_rss(state)
    Process.send_after(self(), :pull_rss, @timeout)
    {:noreply, state}
  end

  def pull_rss(_state) do
    for {channel, links} <- @links do
      for link <- links do
        {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get(link)
        {:ok, feed, _} = FeederEx.parse(body)

        entries =
          feed.entries
          |> Enum.filter(fn entry ->
            case entry.updated do
              nil ->
                false

              _ ->
                case Timex.parse(entry.updated, "{RFC1123}") do
                  {:ok, time} ->
                    subtracted =
                      Timex.subtract(
                        Timex.now(),
                        Timex.Duration.from_milliseconds(@timeout + 1 * 1000)
                      )

                    IO.inspect(subtracted)
                    IO.inspect(time)

                    result = Timex.before?(subtracted, time)
                    IO.inspect(result)
                    result

                  _ ->
                    false
                end
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
