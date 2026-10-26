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

    today = create(:cash_count, money_account: box, counted_amount: 6_500)
    expect(today.system_balance).to eq(6_500)
    expect(today.difference).to eq(0)

    # Kept as it was: later movements of that day do not change it.
    create(:other_income, money_account: box, amount: 200)
    expect(today.reload.system_balance).to eq(6_500)
    expect(AccountBalance.new.for(box)).to eq(6_700) # a count never moves the balance
  end

  it "is not in the future, nor of an inactive account" do
    expect(build(:cash_count, money_account: box, counted_on: Time.zone.today + 1)).not_to be_valid
    box.update!(active: false)
    expect(build(:cash_count, money_account: box)).not_to be_valid
    expect(build(:cash_count, counted_amount: -1)).not_to be_valid
  end
end
