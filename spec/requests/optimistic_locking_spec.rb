require "rails_helper"

RSpec.describe "Optimistic locking" do
  let(:admin) { create(:user, :admin) }
  let(:stale) { "Alguien más guardó cambios en este registro mientras lo editabas" }

  before { sign_in admin }

  it "does not let a purchase form opened before someone else's change overwrite it" do
    purchase = create(:purchase)
    get edit_trading_purchase_path(purchase)
    expect(response.body).to match(/<input[^>]*value="0"[^>]*name="purchase\[lock_version\]"/)

    purchase.update!(price_per_pound: 60) # someone else saves first

    patch trading_purchase_path(purchase), params: { purchase: { price_per_pound: 70, lock_version: 0 } },
                                           headers: { "HTTP_REFERER" => edit_trading_purchase_url(purchase) }
    expect(response).to redirect_to(edit_trading_purchase_url(purchase))
    expect(flash[:alert]).to include(stale)
    expect(purchase.reload.price_per_pound).to eq(60)
    expect(AuditEvent.where(action: "error").last.details).to include("status" => 409, "error" => "ActiveRecord::StaleObjectError")
  end

  it "saves when nobody changed it in between" do
    purchase = create(:purchase)
    patch trading_purchase_path(purchase), params: { purchase: { price_per_pound: 70, lock_version: purchase.lock_version } }
    expect(purchase.reload).to have_attributes(price_per_pound: 70, lock_version: 1)
  end

  it "protects loans and payrolls the same way" do
    loan = create(:loan)
    loan.update!(observations: "Primero")
    patch loans_loan_path(loan), params: { loan: { observations: "Después", lock_version: 0 } }
    expect(flash[:alert]).to include(stale)
    expect(loan.reload.observations).to eq("Primero")

    payroll = create(:payroll)
    payroll.update!(name: "Primero")
    patch farms_payroll_path(payroll), params: { payroll: { name: "Después", lock_version: 0 } }
    expect(flash[:alert]).to include(stale)
    expect(payroll.reload.name).to eq("Primero")
  end
end
