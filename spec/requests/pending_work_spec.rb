require "rails_helper"

# The home page's pending work in detail (PendingWorkController): each kind
# with its records and the button that solves each, only for what the user
# reads and may do.
RSpec.describe "Pending work" do
  let(:today) { Time.zone.today }

  def page = Nokogiri::HTML(response.body)
  def section(key) = page.at_css("#pending-#{key}")

  it "opens in the modal from the home page figure and the pending panel" do
    create(:purchase)
    sign_in create(:user, :admin)

    get root_path
    links = page.css("a[href='#{pending_work_path}']")
    expect(links.map { it.text.squish }).to include(a_string_including("Pendientes"), "Ver el detalle")
    expect(links.map { it["data-turbo-frame"] }.uniq).to eq([ "modal" ])
  end

  it "lists each kind of pending work with the way to solve it" do
    admin = create(:user, :admin)
    ana = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    create(:purchase, producer: ana, purchased_at: today - 3)
    create(:purchase, producer: ana)
    invoiced = create(:purchase)
    InvoiceIssuer.new(producer: invoiced.producer, user: admin, purchase_ids: [ invoiced.id ], payment_status: "pending").call
    invoice = Invoice.last
    loan = create(:loan, cash_amount: 500, monthly_interest_rate: 0, disbursed_on: today - 90, due_on: today - 5)
    member = create(:payroll_member, payroll: create(:payroll, starts_on: today - 3))
    member.update_columns(payroll_role_id: nil) # left without a wage (e.g. data from before the rule)
    sign_in admin

    get pending_work_path, headers: { "Turbo-Frame" => "modal" }
    expect(response).to have_http_status(:ok)
    # One tab per kind, with how many it lists; only the first one shows.
    tabs = page.css("[role=tablist][aria-label='Tipos de tarea'] [role=tab]")
    expect(tabs.map { it.text.squish })
      .to eq([ "Compras sin facturar 1", "Facturas sin cancelar 1", "Préstamos vencidos 1", "Empleados sin salario 1" ])
    expect(tabs.map { it["aria-selected"] }).to eq(%w[true false false false])
    expect(page.css("[role=tabpanel]").map { it["hidden"].nil? }).to eq([ true, false, false, false ])
    expect(page.css("a[href^='#']")).to be_empty # no jump links: inside a frame they loaded the home page

    ana_row = section(:uninvoiced).at_css("##{ActionView::RecordIdentifier.dom_id(ana, :pending)}")
    expect(ana_row.text.squish).to include("Ana Zelaya", "2 compras · desde el #{I18n.l(today - 3, format: :short)}")
    expect(ana_row.at_css("a")["href"]).to eq(new_trading_invoice_path(producer_id: ana.id))
    expect(ana_row.at_css("a")["data-turbo-frame"]).to eq("_top")

    expect(section(:unpaid_invoices).text.squish).to include("Factura #{invoice.display_number}", "emitida hoy")
    expect(section(:unpaid_invoices).at_css("a[href='#{new_trading_invoice_payment_path(invoice)}']")["data-turbo-frame"]).to eq("modal_2")

    expect(section(:overdue_loans).text.squish).to include("Préstamo #{loan.id}", "5 días de atraso", "L 500.00")
    expect(section(:overdue_loans).at_css("a[href='#{new_loans_loan_payment_path(loan)}']")).to be_present

    expect(section(:members_without_wage).at_css("a[href='#{edit_farms_payroll_member_path(member.payroll, member)}']")).to be_present
  end

  it "shows only the modules the user reads, and only the buttons they may use" do
    reader = create(:user).tap { create(:permission, user: it, module_key: "trading", can_read: true) }
    create(:purchase)
    create(:loan, cash_amount: 500, monthly_interest_rate: 0, disbursed_on: today - 90, due_on: today - 5)
    sign_in reader

    get pending_work_path, headers: { "Turbo-Frame" => "modal" }
    expect(section(:uninvoiced)).to be_present
    expect(section(:uninvoiced).css("a")).to be_empty # reading only: no "Facturar"
    expect(section(:overdue_loans)).to be_nil
  end

  it "says when everything is up to date" do
    sign_in create(:user, :admin)
    get pending_work_path

    expect(page.text).to include("No hay nada pendiente")
  end
end
