require "rails_helper"

# Control financiero → Ingresos (Fernando, 2026-10-24): every peso that came
# in, from the modules the user reads, with the total of each source.
RSpec.describe "Finance incomes" do
  def page = Nokogiri::HTML(response.body)

  before do
    create(:sale_payment, sale: create(:sale), amount: 700)
    create(:loan_payment, loan: create(:loan, cash_amount: 3_000), amount: 50, payment_method: "transfer")
    producer = create(:producer)
    create(:loan_payment, loan: create(:loan, person: producer.person), amount: 20, payment_method: "coffee", purchase: create(:purchase, producer:))
    create(:other_income, concept: "Aporte del dueño", amount: 1_000)
    create(:account_transfer, amount: 9)
    create(:expense, amount: 30)
  end

  it "lists what came in, by source, without transfers, expenses nor coffee payments" do
    sign_in create(:user, :admin)
    get finance_incomes_path
    expect(response).to have_http_status(:ok)
    stats = page.css(".stat").to_h { [ it.at_css("dt").text.squish, it.at_css("dd").text.squish ] }
    expect(stats).to include("Total ingresado" => "L 1,750.00", "Cobro de venta" => "L 700.00", "Abono a préstamo" => "L 50.00", "Otro ingreso" => "L 1,000.00")
    expect(page.css("tbody tr").size).to eq(3)
    expect(page.at_css("a[href='#{new_finance_other_income_path}']")).to be_present

    get finance_incomes_path(source: "other_incomes")
    expect(page.css("tbody tr").map { it.text.squish }).to contain_exactly(a_string_including("Aporte del dueño", "L 1,000.00"))
  end

  it "shows only the sources of the modules the user reads" do
    user = create(:user).tap { create(:permission, user: it, module_key: "finance", can_read: true) }
    sign_in user
    get finance_incomes_path
    expect(page.css(".stat dt").map { it.text.squish }).to eq([ "Total ingresado", "Otro ingreso" ])
    expect(page.at_css("a[href='#{new_finance_other_income_path}']")).to be_nil
  end
end
