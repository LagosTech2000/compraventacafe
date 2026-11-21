require "rails_helper"

# A cash count ("arqueo"): what was counted against the system's balance of
# that account at the end of that day, kept as it was.
RSpec.describe CashCount do
  let(:box) { create(:money_account, opening_balance: 5_000) }

  it "takes the system's balance of that day and says the difference" do
    create(:other_income, money_account: box, amount: 1_000, received_on: Time.zone.today - 2)
    create(:other_income, money_account: box, amount: 500) # today

    yesterday = create(:cash_count, money_account: box, counted_on: Time.zone.today - 1, counted_amount: 5_900)
    expect(yesterday).to have_attributes(system_balance: 6_000, difference: -100)

    # Yesterday's 100 short entered as its adjustment.
    today = create(:cash_count, money_account: box, counted_amount: 6_400)
    expect(today.system_balance).to eq(6_400)
    expect(today.difference).to eq(0)

    # Kept as it was: later movements of that day do not change it.
    create(:other_income, money_account: box, amount: 200)
    expect(today.reload.system_balance).to eq(6_400)
    expect(AccountBalance.new.for(box)).to eq(6_600)
  end

  # «Dejar cuadrada la caja desde hoy en adelante» (Fernando, 2026-11-20):
  # the difference enters the balance; the next count starts from there.
  it "leaves the account as counted, the next count starts from there, and only the latest is removed" do
    first = create(:cash_count, money_account: box, counted_on: Time.zone.today - 1, counted_amount: 5_300)
    expect(first).to have_attributes(system_balance: 5_000, adjustment: 300)
    expect(AccountBalance.new.for(box)).to eq(5_300)
    expect(MoneyMovements.new(account: box.id).all.sole).to have_attributes(source: "cash_counts", description: "Ajuste por arqueo", amount_in: 300)

    create(:expense, money_account: box, amount: 1_000)
    short = create(:cash_count, money_account: box, counted_amount: 4_250)
    expect(short).to have_attributes(system_balance: 4_300, adjustment: -50)
    expect(AccountBalance.new.for(box)).to eq(4_250)
    expect(MoneyMovements.new(account: box.id).all.select { it.source == "cash_counts" }.map(&:net)).to eq([ 300, -50 ])

    expect(first.destroy).to be(false)
    expect(first.errors[:base]).to eq([ "Solo se quita el último arqueo de la cuenta: los de después tomaron su ajuste." ])
    expect(short.destroy).to be_truthy
    expect(first.reload.destroy).to be_truthy
    expect(AccountBalance.new.for(box)).to eq(4_000)
  end

  it "is not in the future, nor of an inactive account" do
    expect(build(:cash_count, money_account: box, counted_on: Time.zone.today + 1)).not_to be_valid
    box.update!(active: false)
    expect(build(:cash_count, money_account: box)).not_to be_valid
    expect(build(:cash_count, counted_amount: -1)).not_to be_valid
  end
end
