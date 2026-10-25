require "rails_helper"

# Process guides where the process happens (Fernando, 2026-10-18: the same
# convention in every module).
RSpec.describe "Process guides" do
  let(:admin) { create(:user, :admin) }

  def guides = Nokogiri::HTML(response.body).css("[data-controller='help-guide'] button").map { it["aria-label"] }

  before { sign_in admin }

  it "explains paying invoices, carreros, coffee payments and merging where they are done" do
    invoice = create(:invoice)
    get new_trading_invoice_payment_path(invoice)
    expect(guides).to include("Ayuda: Pagar una factura por abonos")

    hauler = create(:hauler)
    get trading_hauler_path(hauler)
    expect(guides).to include("Ayuda: Comisión y pagos de un carrero")

    loan = create(:loan)
    purchase = create(:purchase, producer: create(:producer, person: loan.person))
    get new_trading_purchase_loan_settlement_path(purchase)
    expect(guides).to include("Ayuda: Pagar préstamos con café")

    get new_administration_person_merge_path(loan.person)
    expect(guides).to include("Ayuda: Fusionar dos registros de la misma persona")
  end

  it "explains the sales flow where shipments and sales are made" do
    sale = create(:sale)
    [ sales_shipments_path, new_sales_shipment_path, sales_shipment_path(sale.shipments.first), new_sales_sale_path, sales_sale_path(sale) ].each do |path|
      get path
      expect(guides).to include("Ayuda: Salida, peso en destino, venta y cobro"), path
    end
  end

  it "explains the money of the business on the movements and the accounts" do
    [ finance_movements_path, finance_money_accounts_path ].each do |path|
      get path
      expect(guides).to include("Ayuda: Cuentas, gastos y movimientos"), path
    end
  end

  it "explains the Planilla interna where it is run" do
    member = create(:staff_member)
    [ finance_staff_members_path, finance_staff_roles_path, finance_staff_member_path(member), new_finance_staff_member_staff_payment_path(member) ].each do |path|
      get path
      expect(guides).to include("Ayuda: Planilla interna del negocio"), path
    end
  end

  it "explains paying a period and the harvest on the timesheet, and saved filters on the reports" do
    payroll = create(:payroll, kind: "harvest", can_price: 40)
    get farms_payroll_timesheet_path(payroll)
    expect(guides).to include("Ayuda: Planilla de corte por lata")

    get reports_report_path("purchases")
    expect(guides).to include("Ayuda: Guardar los filtros de un reporte")
  end

  it "has every process guide in es.yml with a title, summary and steps" do
    I18n.t("help_guides.processes").each_key do |name|
      guide = HelpGuide.process(name)
      expect([ guide.title, guide.summary, guide.steps ]).to all(be_present)
    end
  end
end
