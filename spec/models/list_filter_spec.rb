require "rails_helper"

RSpec.describe ListFilter do
  def params(hash) = ActionController::Parameters.new(hash)

  it "ignores garbage in every field type" do
    filter = InvoiceFilter.new(params(from: "ayer", zone_id: "1; drop", payment_status: "robada", q: " ", page: "-2"))
    expect([ filter.from, filter.zone_id, filter.payment_status, filter.q ]).to all(be_nil)
    expect(filter.page).to eq(1)
    expect(filter).not_to be_active
  end

  it "keeps only valid values when rebuilding links" do
    filter = InvoiceFilter.new(params(from: "2026-01-15", zone_id: "3", payment_status: "paid", q: "Ana"))
    expect(filter.to_params).to eq("from" => "2026-01-15", "zone_id" => "3", "payment_status" => "paid", "q" => "Ana")
  end

  it "counts as active only what differs from the defaults" do
    expect(PurchaseFilter.new(params({}))).not_to be_active
    expect(PurchaseFilter.new(params(from: "", to: ""))).to be_active
    expect(PurchaseFilter.new(params(zone_id: "3"))).to be_active
    expect(ZoneFilter.new(params(q: ""))).not_to be_active
  end

  it "pages results" do
    create_list(:zone, 3)
    filter = ZoneFilter.new(params(page: "2"))
    records, next_page = filter.results(Zone.all, per_page: 2)
    expect(records.size).to eq(1)
    expect(next_page).to be(false)
  end

  describe PurchaseFilter do
    it "shows today by default, and everything once the dates are cleared" do
      create(:purchase, purchased_on: Time.zone.today - 3)
      today = create(:purchase)
      expect(PurchaseFilter.new(params({})).apply(Purchase.all)).to eq([ today ])
      expect(PurchaseFilter.new(params(from: "", to: "")).apply(Purchase.all).size).to eq(2)
    end

    it "filters by producer, zone, coffee state and invoicing" do
      zone = create(:zone)
      ana = create(:producer, person: create(:person, first_names: "Ana"))
      target = create(:purchase, producer: ana, zone:, coffee_state: "cherry")
      create(:purchase, zone:, coffee_state: "cherry")
      create(:invoice, producer: ana, purchases: [ create(:purchase, producer: ana, zone:, coffee_state: "cherry") ])

      result = PurchaseFilter.new(params(q: "ana", zone_id: zone.id.to_s, coffee_state: "cherry", invoiced: "no")).apply(Purchase.all)
      expect(result).to eq([ target ])
    end
  end

  describe InvoiceFilter do
    it "filters by producer, number, zone, status, method and dates" do
      zone = create(:zone)
      ana = create(:producer, person: create(:person, first_names: "Ana"))
      target = create(:invoice, producer: ana, purchases: [ create(:purchase, producer: ana, zone:) ])
      target.mark_paid(method: "cash", on: Time.zone.today)
      other = create(:invoice)

      expect(InvoiceFilter.new(params(q: "ana")).apply(Invoice.all)).to eq([ target ])
      expect(InvoiceFilter.new(params(q: other.number.to_s)).apply(Invoice.all)).to eq([ other ])
      expect(InvoiceFilter.new(params(zone_id: zone.id.to_s)).apply(Invoice.all)).to eq([ target ])
      expect(InvoiceFilter.new(params(payment_status: "pending")).apply(Invoice.all)).to eq([ other ])
      expect(InvoiceFilter.new(params(payment_method: "cash")).apply(Invoice.all)).to eq([ target ])
      expect(InvoiceFilter.new(params(from: (Time.zone.today + 1).iso8601)).apply(Invoice.all)).to be_empty
    end
  end

  it "filters users, people, producers and zones" do
    create(:user, email_address: "ana@example.com", admin: true)
    expect(UserFilter.new(params(q: "ana", role: "admin", status: "active")).apply(User.all).map(&:email_address)).to eq([ "ana@example.com" ])

    producer = create(:producer, kind: "own_farm")
    expect(ProducerFilter.new(params(kind: "own_farm")).apply(Producer.all)).to eq([ producer ])
    expect(PersonFilter.new(params(role: "producers")).apply(Person.all)).to eq([ producer.person ])

    create(:zone, name: "Buenas Noches")
    expect(ZoneFilter.new(params(q: "noches")).apply(Zone.all).map(&:name)).to eq([ "Buenas Noches" ])
  end
end
