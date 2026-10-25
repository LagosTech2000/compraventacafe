require "rails_helper"

RSpec.describe "Sales policies" do
  def seller(**flags)
    create(:user).tap { |u| create(:permission, user: u, module_key: "sales", **flags) }.reload
  end

  let(:full) { seller(can_read: true, can_create: true, can_update: true, can_destroy: true) }

  [ BuyerPolicy, ShipmentPolicy, SalePolicy, SalePaymentPolicy, Sales::HomePolicy, Sales::StockPolicy, Sales::DailyClosePolicy ].each do |policy|
    it "#{policy} belongs to the sales module" do
      expect(policy.module_key).to eq("sales")
      expect(policy.new(create(:user), nil)).to forbid_action(:index)
    end
  end

  describe ShipmentPolicy do
    it "edits and weighs a shipment in no sale, and voids it with the delete permission" do
      shipment = create(:shipment)
      expect(described_class.new(full, shipment)).to permit_actions(%i[edit update receive void])
      expect(described_class.new(seller(can_read: true, can_update: true), shipment)).to forbid_action(:void)
      expect(described_class.new(full, shipment)).to forbid_action(:destroy)
    end

    it "freezes a sold or voided shipment" do
      sold = create(:sale).shipments.first
      expect(described_class.new(full, sold)).to forbid_actions(%i[edit update receive void])
      voided = create(:shipment, voided_at: Time.current)
      expect(described_class.new(full, voided)).to forbid_actions(%i[edit update receive void])
    end
  end

  describe SalePolicy do
    it "never edits nor deletes a sale; voids it only without payments" do
      sale = create(:sale)
      expect(described_class.new(full, sale)).to forbid_actions(%i[edit update destroy])
      expect(described_class.new(full, sale)).to permit_action(:void)
      create(:sale_payment, sale:, amount: 1)
      expect(described_class.new(full, sale.reload)).to forbid_action(:void)
    end
  end

  describe SalePaymentPolicy do
    it "collects with the update permission and removes only the latest payment" do
      sale = create(:sale)
      first = create(:sale_payment, sale:, amount: 1)
      latest = create(:sale_payment, sale:, amount: 1)
      expect(described_class.new(seller(can_read: true, can_update: true), sale.payments.build)).to permit_action(:create)
      expect(described_class.new(seller(can_read: true, can_create: true), sale.payments.build)).to forbid_action(:create)
      expect(described_class.new(full, first)).to forbid_action(:destroy)
      expect(described_class.new(full, latest)).to permit_action(:destroy)
    end
  end
end
