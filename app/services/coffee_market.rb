require "net/http"

# Coffee futures on the exchange, for the home page (Fernando, 2026-10-13).
# Only shows what the market says: nothing here sets or suggests the price
# the business pays.
#
# Source: Yahoo Finance's public chart endpoint, free and without a key. It is
# not an official API and can change or fail, so the page asks for it apart
# (a lazy frame) and shows "no disponible" instead of breaking. Each quote is
# kept in the cache for a while: every user's home page reuses it.
#
#   CoffeeMarket.quotes # => [Quote, ...] (only the contracts that answered)
class CoffeeMarket
  # Arabica ("Coffee C", ICE Futures US, New York): the reference for
  # Honduran coffee. Quoted in US cents per pound.
  CONTRACTS = { arabica: "KC=F" }.freeze

  SOURCE_URL = "https://query1.finance.yahoo.com/v8/finance/chart/%<symbol>s?range=1mo&interval=1d"
  SOURCE_PAGE = "https://finance.yahoo.com/quote/%<symbol>s"
  CACHE_FOR = 15.minutes
  # A failed request is not repeated on every page view.
  RETRY_AFTER = 2.minutes
  TIMEOUT = 5

  Quote = Data.define(:key, :symbol, :contract, :exchange, :currency, :price, :previous_close,
                      :day_low, :day_high, :year_low, :year_high, :at, :history) do
    def change = previous_close && (price - previous_close)
    def change_percent = previous_close&.nonzero? && (change / previous_close * 100)
    # Cents per pound to dollars per pound.
    def dollars_per_pound = currency == "USX" ? price / 100 : price
    def source_url = format(SOURCE_PAGE, symbol:)
  end

  def self.quotes
    CONTRACTS.filter_map { |key, symbol| quote(key, symbol) }
  end

  def self.quote(key, symbol)
    cached = Rails.cache.read(cache_key(symbol))
    return (cached unless cached == :unavailable) if cached

    quote = fetch(key, symbol)
    Rails.cache.write(cache_key(symbol), quote || :unavailable, expires_in: quote ? CACHE_FOR : RETRY_AFTER)
    quote
  end

  def self.cache_key(symbol) = "coffee_market/#{symbol}"

  def self.fetch(key, symbol)
    parse(key, symbol, request(format(SOURCE_URL, symbol: CGI.escape(symbol))))
  rescue StandardError => error
    Rails.logger.warn("CoffeeMarket: #{symbol} unavailable (#{error.class}: #{error.message})")
    nil
  end

  def self.request(url)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      # Without a browser-like agent the endpoint answers 429.
      http.get(uri.request_uri, "User-Agent" => "Mozilla/5.0 (compatible; compraventacafe)", "Accept" => "application/json")
    end
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  end

  # The last close before the current one is the previous session's: the
  # change is the one of the last session, also on weekends.
  def self.parse(key, symbol, body)
    result = JSON.parse(body).dig("chart", "result", 0) or return
    meta = result.fetch("meta")
    price = meta["regularMarketPrice"] or return

    closes = Array(result.dig("indicators", "quote", 0, "close"))
    history = Array(result["timestamp"]).zip(closes).filter_map do |time, close|
      [ Time.zone.at(time).to_date, close.to_d.round(2) ] if close
    end

    Quote.new(key:, symbol:, contract: meta["shortName"], exchange: meta["fullExchangeName"] || meta["exchangeName"],
              currency: meta["currency"], price: price.to_d.round(2),
              previous_close: history.size > 1 ? history[-2].last : meta["chartPreviousClose"]&.to_d&.round(2),
              day_low: meta["regularMarketDayLow"]&.to_d, day_high: meta["regularMarketDayHigh"]&.to_d,
              year_low: meta["fiftyTwoWeekLow"]&.to_d, year_high: meta["fiftyTwoWeekHigh"]&.to_d,
              at: meta["regularMarketTime"] && Time.zone.at(meta["regularMarketTime"]), history:)
  end
end
