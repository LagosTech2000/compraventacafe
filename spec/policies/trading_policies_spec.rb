require "rails_helper"

RSpec.describe "Trading policies" do
  def trader(**flags)
    create(:user).tap { |u| create(:permission, user: u, module_key: "trading", **flags) }.reload
  end

  let(:full) { trader(can_read: true, can_create: true, can_update: true, can_destroy: true) }

  [ ZonePolicy, ProducerPolicy, PurchasePolicy, InvoicePolicy, Trading::DailyClosePolicy ].each do |policy|
    it "#{policy} belongs to the trading module" do
      expect(policy.module_key).to eq("trading")
      expect(policy.new(create(:user), nil)).to forbid_action(:index)
    end
  end

  describe PurchasePolicy do
    it "lets a user with update/destroy change an uninvoiced purchase" do
      expect(described_class.new(full, build(:purchase))).to permit_actions(%i[edit update destroy])
    end

    it "freezes an invoiced purchase, even for an admin" do
      purchase = create(:invoice).purchases.first
      expect(described_class.new(full, purchase)).to forbid_actions(%i[edit update destroy])
      expect(described_class.new(create(:user, :admin), purchase)).to forbid_actions(%i[edit update destroy void])
    end

    it "voids with the delete permission, only what is neither invoiced nor voided" do
      purchase = create(:purchase)
      expect(described_class.new(full, purchase)).to permit_action(:void)
      expect(described_class.new(trader(can_read: true, can_update: true), purchase)).to forbid_action(:void)
      purchase.void!(full)
      expect(described_class.new(full, purchase)).to forbid_actions(%i[edit update destroy void])
    end
  end

  describe InvoicePolicy do
    it "never edits invoices: they are paid with payments" do
      expect(described_class.new(full, create(:invoice))).to forbid_action(:update)
    end

    it "never deletes invoices" do
      expect(described_class.new(create(:user, :admin), create(:invoice))).to forbid_action(:destroy)
    end
  end

  describe InvoicePaymentPolicy do
    let(:invoice) { create(:invoice) }

    def payment(amount) = invoice.payments.create!(amount:, paid_on: Time.zone.today, payment_method: "cash", created_by: full)

    it "pays an invoice with editing in trading, until it is paid" do
      expect(described_class.new(full, InvoicePayment.new(invoice:))).to permit_action(:create)
      expect(described_class.new(trader(can_read: true, can_create: true), InvoicePayment.new(invoice:))).to forbid_action(:create)
      invoice.mark_paid(method: "cash", on: Time.zone.today)
      expect(described_class.new(full, InvoicePayment.new(invoice: invoice.reload))).to forbid_action(:create)
    end

    it "removes only the latest payment, with deleting in trading, and never edits one" do
      first = payment(100)
      last = payment(50)
      expect(described_class.new(full, first)).to forbid_action(:destroy)
      expect(described_class.new(full, last)).to permit_action(:destroy)
      expect(described_class.new(trader(can_read: true, can_update: true), last)).to forbid_action(:destroy)
      expect(described_class.new(full, last)).to forbid_action(:update)
    end
  end

  it "scopes trading records to readers of the module" do
    create(:zone)
    expect(ZonePolicy::Scope.new(trader(can_read: true), Zone).resolve.count).to eq(1)
    expect(ZonePolicy::Scope.new(trader(can_create: true), Zone).resolve).to be_empty
  end
end
