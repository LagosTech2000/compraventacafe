require "rails_helper"

# The coffee exchange card of the home page, loaded apart (a lazy frame).
RSpec.describe "Coffee market card" do
  def page = Nokogiri::HTML(response.body)

  before { sign_in create(:user) }

  it "is a lazy frame on the home page, so the page never waits for it" do
    get root_path

    frame = page.at_css("turbo-frame#coffee-market")
    expect(frame["src"]).to eq(coffee_market_path)
    expect(frame["loading"]).to eq("lazy")
    expect(CoffeeMarket).not_to have_received(:request)
  end

  it "shows the price, its change and the source" do
    coffee_market_responds_with
    get coffee_market_path, headers: { "Turbo-Frame" => "coffee-market" }

    card = page.at_css("turbo-frame#coffee-market [data-coffee-quote='arabica']")
    expect(card.text.squish).to include("Café arábica «C» (futuros) · ICE Futures", "293.20", "centavos de dólar por libra",
                                        "▲ 6.25 (2.18%)", "US$ 2.9320 por libra", "Coffee Dec 26")
    expect(card.at_css("svg polyline")).to be_present
    expect(card.at_css("a[href='https://finance.yahoo.com/quote/KC=F']")).to be_present
  end

  it "says so when the exchange does not answer" do
    get coffee_market_path, headers: { "Turbo-Frame" => "coffee-market" }

    expect(response).to have_http_status(:ok)
    expect(page.at_css("turbo-frame#coffee-market").text).to include("no está disponible")
  end

  it "needs a session" do
    delete session_path
    get coffee_market_path

    expect(response).to redirect_to(new_session_path)
  end
end
