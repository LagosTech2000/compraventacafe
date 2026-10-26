require "rails_helper"

# The way up on every detail page (Fernando, 2026-10-18, as in Fincas): a
# purchase or an invoice shows its producer, a loan its person's account, a
# receipt what it was paid on. Only on a full page: a modal has «Atrás».
RSpec.describe "Breadcrumbs" do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")) }

  def crumbs = Nokogiri::HTML(response.body).css("nav.breadcrumbs ol li").map { it.text.squish.delete_suffix(" ›") }

  before { sign_in admin }

  it "goes up through the producer from a purchase, an invoice and its receipt" do
    invoice = create(:invoice, producer:)
    payment = invoice.payments.create!(amount: 10, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)

    get trading_purchase_path(invoice.purchases.first)
    expect(crumbs).to eq([ "Productores", "Ana Zelaya", "Compra #{invoice.purchases.first.id}" ])

    get trading_invoice_path(invoice)
    expect(crumbs).to eq([ "Productores", "Ana Zelaya", "Factura #{invoice.display_number}" ])

    get trading_invoice_payment_path(invoice, payment)
    expect(crumbs.first(3)).to eq([ "Productores", "Ana Zelaya", "Factura #{invoice.display_number}" ])
    expect(crumbs.size).to eq(4)
  end

  it "goes up through the list from a coffee conversion and its result" do
    conversion = create(:coffee_conversion)
    get sales_coffee_conversion_path(conversion)
    expect(crumbs).to eq([ "Conversiones", "Conversión #{conversion.display_number}" ])
    get edit_sales_coffee_conversion_result_path(conversion)
    expect(crumbs).to eq([ "Conversiones", "Conversión #{conversion.display_number}", "Resultado" ])
  end

  it "goes up through the buyer from a shipment, a sale and its receipt" do
    buyer = create(:buyer, name: "Beneficio Henola")
    sale = create(:sale, buyer:)
    payment = create(:sale_payment, sale:, amount: 1)

    get sales_shipment_path(sale.shipments.first)
    expect(crumbs).to eq([ "Compradores", "Beneficio Henola", "Salida #{sale.shipments.first.display_number}" ])
    get sales_sale_path(sale)
    expect(crumbs).to eq([ "Compradores", "Beneficio Henola", "Venta #{sale.display_number}" ])
    get sales_sale_payment_path(sale, payment)
    expect(crumbs.first(3)).to eq([ "Compradores", "Beneficio Henola", "Venta #{sale.display_number}" ])
  end

  it "goes up through its list from an expense, an investment and an account" do
    expense = create(:expense, description: "Diésel")
    investment = create(:expense, kind: "investment", description: "Báscula")
    get finance_expense_path(expense)
    expect(crumbs).to eq([ "Gastos", "Diésel" ])
    get finance_investment_path(investment)
    expect(crumbs).to eq([ "Inversiones", "Báscula" ])
    get finance_money_account_path(expense.money_account)
    expect(crumbs).to eq([ "Cuentas", expense.money_account.name ])
  end

  it "goes up through the account from a loan and its receipt, and through the carrero from a payment" do
    loan = create(:loan, person: producer.person)
    payment = create(:loan_payment, loan:, amount: 100)
    hauler = create(:hauler, person: producer.person)
    create(:purchase, producer:, hauler:, gross_weight: 1_000)
    hauler_payment = create(:hauler_payment, hauler:, amount: 1)

    get loans_loan_path(loan)
    expect(crumbs).to eq([ "Estados de cuenta", "Ana Zelaya", "Préstamo #{loan.id}" ])

    get loans_loan_payment_path(loan, payment)
    expect(crumbs.first(3)).to eq([ "Estados de cuenta", "Ana Zelaya", "Préstamo #{loan.id}" ])

    get trading_hauler_path(hauler)
    expect(crumbs).to eq([ "Carreros", "Ana Zelaya" ])
    get trading_hauler_payment_path(hauler, hauler_payment)
    expect(crumbs.first(2)).to eq([ "Carreros", "Ana Zelaya" ])
  end

  it "goes up through the Planilla interna from an employee, their payment and the roles" do
    member = create(:staff_member, person: producer.person.tap { it.update!(collaborator_role: "1") }, starts_on: Time.zone.today - 40)
    issuer = StaffPaymentIssuer.new(member:, period: member.period_to_pay, user: admin, payment_method: "cash",
                                    money_account_id: create(:money_account).id)
    issuer.call

    get finance_staff_member_path(member)
    expect(crumbs).to eq([ "Planilla interna", "Ana Zelaya" ])
    get finance_staff_member_staff_payment_path(member, issuer.payment)
    expect(crumbs.first(2)).to eq([ "Planilla interna", "Ana Zelaya" ])
    get finance_staff_roles_path
    expect(crumbs).to eq([ "Planilla interna", "Roles de la planilla" ])
  end

  it "goes up from a person, a user and a farm in Administración" do
    get administration_person_path(producer.person)
    expect(crumbs).to eq([ "Personas", "Ana Zelaya" ])

    get edit_administration_producer_path(producer)
    expect(crumbs.first(2)).to eq([ "Personas", "Ana Zelaya" ])

    get administration_user_path(admin)
    expect(crumbs).to eq([ "Usuarios", admin.name ])
  end

  it "leaves them out in the modal" do
    get trading_producer_path(producer), headers: { "Turbo-Frame" => "modal" }

    expect(Nokogiri::HTML(response.body).at_css("nav.breadcrumbs")).to be_nil
  end
end
