require "rails_helper"

RSpec.describe MoneyAccount do
  # The loans' account (Fernando, 2026-11-01).
  describe "the loans' account" do
    it "goes alone, in one account only, and is the one the loans start with" do
      box = create(:money_account, name: "Caja", default_for: %w[cash])
      loans = create(:money_account, name: "Préstamos", default_for: %w[cash transfer loans])
      expect(loans.default_for).to eq(%w[loans])
      expect(described_class.for_loans).to eq(loans)
      expect(described_class.default_for("cash")).to eq(box)
      expect(described_class.defaults_by_method).not_to have_value(loans.id)

      other = build(:money_account, default_for: %w[loans])
      expect(other).not_to be_valid
      expect(other.errors[:base]).to eq([ "Solo una cuenta puede ser la de préstamos, y ya lo es Préstamos: quítaselo ahí primero." ])
      expect { other.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)

      loans.update!(active: false)
      expect(described_class.for_loans).to be_nil
      expect(described_class.human_suggestion("loans")).to eq("Préstamos")
    end
  end
end
