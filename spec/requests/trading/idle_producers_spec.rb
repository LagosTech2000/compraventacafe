require "rails_helper"

# «Productores que no venden hace…» (Fernando, 2026-11-13): the Inicio's card
# with the last 30 by 7, 15 days or a month, and the whole list.
RSpec.describe "Producers that stopped selling" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)

  def producer_named(name, zone: nil) = create(:producer, person: create(:person, first_names: name, last_names: "Zelaya", zone:))

  it "lists those whose last purchase is older than the days chosen, the latest to stop first" do
    zone = create(:zone, name: "El Rosario")
    recent = producer_named("Ana", zone:)
    create(:purchase, producer: recent, purchased_at: 10.days.ago)
    older = producer_named("Bruno")
    create(:purchase, producer: older, purchased_at: 40.days.ago)
    active = producer_named("Carla")
    create(:purchase, producer: active, purchased_at: 40.days.ago)
    create(:purchase, producer: active, purchased_at: 1.day.ago)
    voided = producer_named("Dora")
    create(:purchase, producer: voided, purchased_at: 40.days.ago)
    create(:purchase, producer: voided, purchased_at: 1.day.ago).void!(admin) # a voided purchase is no sale
    producer_named("Elsa") # never sold: not here

    expect(IdleProducers.scope(7).map(&:full_name)).to contain_exactly("Ana Zelaya", "Bruno Zelaya", "Dora Zelaya")
    expect(IdleProducers.scope(30).map(&:full_name)).to contain_exactly("Bruno Zelaya", "Dora Zelaya")
    sign_in admin

    get card_trading_idle_producers_path(days: 15), headers: { "Turbo-Frame" => "idle-producers" }
    expect(response).to have_http_status(:ok)
    names = page.css("[data-idle-producers='15'] li").map { it.text.squish }
    expect(names.size).to eq(2)
    expect(names).to all(include("Zelaya"))
    expect(page.at_css("#idle_producers_days option[selected]").text).to eq("15 días")
    expect(page.css("#idle_producers_days option").map(&:text)).to eq([ "7 días", "15 días", "un mes" ])
    expect(page.at_css("a[href='#{trading_idle_producers_path(days: 15)}']").text).to eq("Ver todos")

    get trading_idle_producers_path(days: 7)
    rows = page.css("table tbody tr").map { it.css("td").first(4).map { it.text.squish } }
    expect(rows.first).to eq([ "Ana Zelaya", "El Rosario", I18n.l(10.days.ago.to_date), "10" ])
    expect(rows.size).to eq(3)
    get trading_idle_producers_path(days: 7, zone_id: zone.id)
    expect(page.css("table tbody tr").size).to eq(1)
  end

  it "shows only the last 30 in the card" do
    31.times { |index| create(:purchase, purchased_at: (10 + index).days.ago) }
    sign_in admin
    get card_trading_idle_producers_path
    expect(page.css("[data-idle-producers] li").size).to eq(IdleProducers::CARD_LIMIT)
  end

  it "is in the Inicio for whoever sees Productores, and nobody else" do
    sign_in admin
    get root_path
    expect(page.at_css("turbo-frame#idle-producers")["src"]).to eq(card_trading_idle_producers_path)

    user = create(:user)
    create(:permission, user:, module_key: "trading", submodule_key: "purchases", can_read: true)
    sign_in user
    get root_path
    expect(page.at_css("turbo-frame#idle-producers")).to be_nil
    get card_trading_idle_producers_path
    expect(response).to redirect_to(root_path)
  end
end
