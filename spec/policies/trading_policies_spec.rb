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
      expect(described_class.new(create(:user, :admin), purchase)).to forbid_actions(%i[edit update destroy])
    end
  end

  describe InvoicePolicy do
    it "allows marking a pending invoice as paid, not a paid one" do
      invoice = create(:invoice)
      expect(described_class.new(full, invoice)).to permit_action(:update)
      invoice.mark_paid(method: "cash", on: Time.zone.today)
      expect(described_class.new(full, invoice)).to forbid_action(:update)
    end

    it "never deletes invoices" do
      expect(described_class.new(create(:user, :admin), create(:invoice))).to forbid_action(:destroy)
    end
  end

  it "scopes trading records to readers of the module" do
    create(:zone)
    expect(ZonePolicy::Scope.new(trader(can_read: true), Zone).resolve.count).to eq(1)
    expect(ZonePolicy::Scope.new(trader(can_create: true), Zone).resolve).to be_empty
  end
end
