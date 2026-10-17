require "rails_helper"

# Carreros (Fernando, 2026-10-16): commission = net pounds ÷ 16.5 (cans) ×
# can price × percent, paid by the business apart from the producer.
RSpec.describe Hauler do
  let(:hauler) { create(:hauler, commission_percent: 10, can_price: 50) }

  # Cherry with a yield of 1: the net weight is the gross minus 1 lb per sack.
  def hauled(net, **attributes)
    gross = net
    gross += 1 while gross - (gross / 165.0).ceil < net
    create(:purchase, coffee_state: "cherry", yield_factor: 1, gross_weight: gross, hauler:, **attributes)
  end

  it "earns cans × can price × percent: 1,650 lb are 100 cans × L 50 × 10 % = L 500" do
    expect(Hauler.commission(net_weight: 1_650, percent: 10, can_price: 50)).to eq([ 100, 500 ])
    expect(Hauler.commission(net_weight: 1_000, percent: "12.5", can_price: "47.25")).to eq([ BigDecimal("60.61"), BigDecimal("357.95") ])
  end

  it "requires its percent and can price" do
    expect(build(:hauler, commission_percent: nil, can_price: nil)).not_to be_valid
    expect(build(:hauler, commission_percent: 0)).not_to be_valid
    expect(build(:hauler, commission_percent: 101)).not_to be_valid
    expect(build(:hauler, can_price: 0)).not_to be_valid
    expect(build(:hauler, commission_percent: "2.5", can_price: "35.75")).to be_valid
  end

  it "is owed the commissions of its active purchases minus its payments" do
    hauled(1_650)
    hauled(825)
    hauled(1_650).void!(create(:user))
    create(:hauler_payment, hauler:, amount: 200)

    expect(hauler.commissions_total).to eq(750)
    expect(hauler.paid_total).to eq(200)
    expect(hauler.balance).to eq(550)
    expect(Hauler.with_totals.find(hauler.id)).to have_attributes(commissions_total: 750, paid_total: 200, balance_total: 550)
  end

  describe "on a purchase" do
    it "keeps the hauler's percent and can price of its day" do
      purchase = hauled(1_650)
      expect(purchase).to have_attributes(hauler_commission_percent: 10, hauler_can_price: 50, hauler_cans: 100, hauler_commission: 500)

      hauler.update!(commission_percent: 20, can_price: 60)
      purchase.reload.update!(observations: "Sin cambios")
      expect(purchase.reload.hauler_commission).to eq(500)

      purchase.update!(gross_weight: 832) # 826 lb net: the terms of its day, not the new ones
      expect(purchase.reload).to have_attributes(net_weight: 826, hauler_commission_percent: 10, hauler_can_price: 50,
                                                 hauler_cans: BigDecimal("50.06"), hauler_commission: BigDecimal("250.30"))
    end

    it "takes the new hauler's terms when the hauler changes, and drops them without one" do
      purchase = hauled(1_650)
      other = create(:hauler, commission_percent: 5, can_price: 40)
      purchase.update!(hauler: other)
      expect(purchase.reload).to have_attributes(hauler_commission_percent: 5, hauler_can_price: 40, hauler_commission: 200)

      purchase.update!(hauler: nil)
      expect(purchase.reload).to have_attributes(hauler_commission_percent: nil, hauler_can_price: nil, hauler_cans: nil, hauler_commission: nil)
    end

    it "takes only an active hauler" do
      hauler.update!(active: false)
      purchase = build(:purchase, hauler:)
      expect(purchase).not_to be_valid
      expect(purchase.errors[:hauler]).to include("está desactivado: elige otro o actívalo en su ficha")
    end

    it "cannot leave a hauler owing what was already paid to them" do
      purchase = hauled(1_650)
      create(:hauler_payment, hauler:, amount: 400)

      expect { purchase.void!(create(:user)) }.to raise_error(ActiveRecord::RecordInvalid, /ya se le pagó al carrero/)
      expect(purchase.reload).not_to be_voided
      expect(purchase.update(hauler: nil)).to be(false)
      expect(purchase.destroy).to be(false)
      expect(purchase.errors[:base]).to include(a_string_including("ya se le pagó al carrero #{hauler.full_name}"))

      hauler.payments.last.destroy!
      purchase.void!(create(:user))
      expect(hauler.balance).to eq(0)
    end
  end

  describe "payments" do
    before { hauled(1_650) }

    it "never pay more than what is owed, nor before the last one, and keep the balance after" do
      first = create(:hauler_payment, hauler:, amount: 300, paid_on: Time.zone.today - 1)
      expect(first.balance_after).to eq(200)

      too_much = build(:hauler_payment, hauler:, amount: 201)
      expect(too_much).not_to be_valid
      expect(too_much.errors[:amount].sole).to include("es mayor que lo que se le debe al carrero")

      earlier = build(:hauler_payment, hauler:, amount: 10, paid_on: Time.zone.today - 2)
      expect(earlier).not_to be_valid
      expect(earlier.errors[:paid_on]).to include("no puede ser antes del último pago")

      last = create(:hauler_payment, hauler:, amount: 200)
      expect(last.balance_after).to eq(0)
      expect([ first.latest?, last.latest? ]).to eq([ false, true ])
    end
  end

  describe "as a role of a person, from the form" do
    let(:person) { create(:person, :client) }

    it "is added with its percent and can price, both required" do
      person.assign_attributes(hauler_role: "1")
      expect(person).not_to be_valid

      person.assign_attributes(hauler_commission_percent: "8", hauler_can_price: "45")
      person.save!
      expect(person.reload.hauler).to have_attributes(commission_percent: 8, can_price: 45, active: true)
    end

    it "stays while it has purchases or payments" do
      create(:hauler, person:)
      create(:purchase, hauler: person.hauler)
      person.reload.assign_attributes(hauler_role: "0", client_role: "1")
      expect(person).not_to be_valid
      expect(person.errors[:base]).to include(a_string_including("No se puede quitar el rol de carrero"))
    end
  end
end
