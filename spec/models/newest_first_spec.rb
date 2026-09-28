require "rails_helper"

# Convention: every list shows the most recent records first.
RSpec.describe "Newest first" do
  def params(hash = {}) = ActionController::Parameters.new(hash)

  it "orders every list filter newest first" do
    { UserFilter => :user, PersonFilter => :person, ProducerFilter => :producer, ZoneFilter => :zone }.each do |filter, factory|
      older = create(factory, created_at: 2.days.ago)
      newer = create(factory, created_at: 1.hour.ago)
      ids = filter.new(params).apply(older.class.where(id: [ older.id, newer.id ])).map(&:id)
      expect(ids).to eq([ newer.id, older.id ]), filter.name
    end
  end

  it "orders purchases by purchase date, then by last registered" do
    old_date = create(:purchase, purchased_on: Time.zone.today - 5)
    first_today = create(:purchase)
    second_today = create(:purchase)
    result = PurchaseFilter.new(params(from: "", to: "")).apply(Purchase.all)
    expect(result).to eq([ second_today, first_today, old_date ])
    expect(PurchaseFilter.new(params).apply(Purchase.all)).to eq([ second_today, first_today ])
  end

  it "orders invoices by number, highest first" do
    first = create(:invoice)
    second = create(:invoice)
    expect(InvoiceFilter.new(params).apply(Invoice.all)).to eq([ second, first ])
  end

  it "orders the audit log newest first" do
    older = AuditEvent.record!(action: "sign_in_failed", label: "a", user: nil)
    newer = AuditEvent.record!(action: "sign_in_failed", label: "b", user: nil)
    expect(AuditEventFilter.new(params).apply(AuditEvent.where(id: [ older.id, newer.id ]))).to eq([ newer, older ])
  end
end
