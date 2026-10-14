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

  describe "sorting (every column of a list)" do
    it "sorts the whole list by a column, both ways, and keeps it in the links" do
      %w[Bravo alfa Charlie].each { create(:zone, name: it) }
      filter = ZoneFilter.new(params(sort: "name", dir: "desc"))
      expect(filter.results(Zone.all).first.map(&:name)).to eq(%w[Charlie Bravo alfa])
      expect(filter.to_params).to eq("sort" => "name", "dir" => "desc")
      expect(filter).not_to be_active # a sort is not a filter

      records, next_page = ZoneFilter.new(params(sort: "name", page: "2")).results(Zone.all, per_page: 2)
      expect(records.map(&:name)).to eq(%w[Charlie])
      expect(next_page).to be(false)
    end

    it "ignores a column it does not know, and a wrong direction" do
      expect(ZoneFilter.new(params(sort: "drop table", dir: "up")).sort).to be_nil
      expect(ZoneFilter.new(params(sort: "name", dir: "sideways")).dir).to eq("asc")
    end

    it "sorts by a column of another table, empty values last" do
      with_zone = create(:producer, person: create(:person, zone: create(:zone, name: "Zacapa")))
      other = create(:producer, person: create(:person, zone: create(:zone, name: "Azul")))
      without = create(:producer)

      %w[asc desc].each do |dir|
        records, = ProducerFilter.new(params(sort: "zone", dir:)).results(Producer.all)
        expected = dir == "asc" ? [ other, with_zone ] : [ with_zone, other ]
        expect(records).to eq(expected + [ without ])
      end
    end

    it "sorts computed values in Ruby, without minding accents" do
      today = Time.zone.today
      small = create(:loan, cash_amount: 100, monthly_interest_rate: 0, person: create(:person, first_names: "Álvaro"))
      big = create(:loan, cash_amount: 900, monthly_interest_rate: 0, person: create(:person, first_names: "Beto"))
      paid = create(:loan, cash_amount: 500, monthly_interest_rate: 0, disbursed_on: today - 10, due_on: today + 10)
      paid.update_columns(paid_off_on: today)

      expect(LoanFilter.new(params(sort: "owed", dir: "desc")).results(Loan.where(id: [ small, big ])).first).to eq([ big, small ])
      expect(LoanFilter.new(params(sort: "person")).results(Loan.where(id: [ small, big ])).first).to eq([ small, big ])
      expect(LoanFilter.new(params(sort: "status", dir: "desc")).results(Loan.all).first.first).to eq(paid)
    end
  end

  describe PurchaseFilter do
    it "shows today by default, and everything once the dates are cleared" do
      create(:purchase, purchased_at: Time.zone.today - 3)
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
    expect(ProducerFilter.new(params(q: producer.person.first_names)).apply(Producer.all).to_a).to eq([ producer ])
    expect(PersonFilter.new(params(role: "producers")).apply(Person.all)).to eq([ producer.person ])

    create(:zone, name: "Buenas Noches")
    expect(ZoneFilter.new(params(q: "noches")).apply(Zone.all).map(&:name)).to eq([ "Buenas Noches" ])
  end

  describe "for links and the active filters" do
    def purchases(**params) = PurchaseFilter.new(ActionController::Parameters.new(params))

    it "keeps a field cleared on purpose, so the next page does not go back to its default" do
      cleared = purchases(from: "", to: "", zone_id: "")
      expect(cleared.to_params).to eq("from" => "", "to" => "")
      expect(purchases(**cleared.to_params.symbolize_keys)).to have_attributes(from: nil, to: nil)
      expect(purchases.to_params).to eq("from" => Time.zone.today.iso8601, "to" => Time.zone.today.iso8601)
    end

    it "lists what changed from the defaults and puts fields back to them" do
      filter = purchases(zone_id: "3", invoiced: "no", from: "")
      expect(filter.active_fields).to eq(%i[from zone_id invoiced])
      expect(filter.params_without(:zone_id)).not_to include("zone_id")
      expect(filter.default_values(:from, :zone_id)).to eq("from" => Time.zone.today.iso8601, "zone_id" => "")
    end
  end
end
