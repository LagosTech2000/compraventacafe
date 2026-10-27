require "rails_helper"

# Converting coffee from Comercialización: weigh what goes in, enter what came
# out; the stock, its cards and the kardex follow, in gross, net and QQ.
RSpec.describe "Coffee conversions" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)
  def card(key) = page.at_css("[data-coffee-state=#{key}]")
  def card_net(key) = card(key).at_css("[data-live-value]").text.squish

  before do
    create(:purchase, gross_weight: 2_000) # 973.63 lb net of wet parchment
    sign_in admin
  end

  it "weighs what goes in, keeps it in process, then enters what came out" do
    get new_sales_coffee_conversion_path(from_state: "wet_parchment")
    expect(response).to have_http_status(:ok)
    expect(page.at_css("input[type=radio][value=wet_parchment][checked]")).to be_present

    site = create(:processing_site, name: "Secadora El Pino")
    post sales_coffee_conversions_path, params: { coffee_conversion: { from_state: "wet_parchment", weighed_at: Time.current.change(sec: 0),
                                                                         processing_site_id: site.id, estimated_yield_percent: "50", input_humidity_percent: "51",
                                                                         input_gross_weight: "1000", observations: "Patio 1" } }
    conversion = CoffeeConversion.sole
    expect(response).to redirect_to(sales_coffee_conversion_path(conversion))
    expect(conversion).to have_attributes(input_net_weight: BigDecimal("486.82"), created_by: admin, status: "in_process", processing_site: site,
                                          estimated_yield_percent: 50, input_humidity_percent: 51, estimated_output_gross: 500)
    expect(AuditEvent.where(auditable: conversion, action: "create")).to exist

    get sales_stock_path
    expect(card_net("wet_parchment")).to eq("486.81 lb")
    expect(card_net("in_process")).to eq("486.82 lb")
    expect(card("in_process")["href"]).to eq(sales_coffee_conversions_path(status: "in_process"))

    get edit_sales_coffee_conversion_result_path(conversion)
    expect(response).to have_http_status(:ok)
    patch sales_coffee_conversion_result_path(conversion), params: { coffee_conversion: { finished_at: Time.current.change(sec: 0),
                                                                                           output_gross_weight: "600", output_sacks: "4", output_humidity_percent: "12",
                                                                                           output_damage_percent: "", lock_version: conversion.lock_version } }
    expect(conversion.reload).to have_attributes(status: "finished", output_net_weight: BigDecimal("524.48"), output_damage_percent: 0, finished_by: admin)

    get sales_stock_path
    expect(card_net("dry_parchment")).to eq("524.48 lb")
    expect(card("in_process")).to be_nil
    rows = page.css("#stock-ledger tbody tr").map { it.text.squish }
    expect(rows).to include(a_string_including("De proceso", "Pergamino seco", "+600.00", "+524.48", "+4.20"),
                            a_string_including("A proceso", "Pergamino húmedo", "−1,000.00", "−486.82", "−3.89"))

    get sales_coffee_conversion_path(conversion)
    expect(page.at_css("[data-conversion-side=output]").text.squish).to include("600.00 lb", "524.48 lb", "4.20", "Sacos que salieron4", "12.00")
    expect(page.at_css("[data-conversion-comparison]").text.squish).to include("486.82 lb", "524.48 lb", "37.66 lb más", "7.7 %")
    # Estimated against real (client, 2026-10-26): 500 lb expected, 600 came out; 400 lb shrink.
    expect(page.at_css("[data-conversion-estimate]").text.squish)
      .to include("Debía salir (50 %) 500.00 lb", "Salió (60 %) 600.00 lb", "100.00 lb brutas más de lo estimado", "Merma 400.00 lb (40 %)",
                  "los procesos de Pergamino húmedo dan 60 %")
    expect(page.at_css("[data-conversion-side=input]").text.squish).to include("Lugar Secadora El Pino", "Humedad al entrar (%)51.00")

    get sales_processing_site_path(site)
    expect(page.at_css("#coffee_conversion_#{conversion.id}").text.squish).to include("Secadora El Pino", "60 %")
    get sales_coffee_conversions_path(processing_site_id: site.id)
    expect(page.css("tbody tr").size).to eq(1)
    expect(response.body).not_to include("roporción") # the net/gross proportion is not shown: it confuses
  end

  it "voids one in process and takes a result off" do
    conversion = create(:coffee_conversion, from_state: "wet_parchment", input_gross_weight: 500)
    patch void_sales_coffee_conversion_path(conversion)
    expect(conversion.reload.status).to eq("voided")
    expect(CoffeeStock.new.row("wet_parchment").gross_stock).to eq(2_000)

    finished = create(:coffee_conversion, :finished, from_state: "wet_parchment")
    patch reopen_sales_coffee_conversion_path(finished)
    expect(finished.reload.status).to eq("in_process")
  end

  it "registers processing sites and requires one in a new process" do
    post sales_processing_sites_path, params: { processing_site: { name: "  Patio  ", own: "1" } }
    site = ProcessingSite.sole
    expect(site).to have_attributes(name: "Patio", own: true)
    expect(AuditEvent.where(auditable: site, action: "create")).to exist
    get sales_processing_sites_path
    expect(page.at_css("#processing_site_#{site.id}").text.squish).to include("Patio", "Del negocio", "0")

    post sales_coffee_conversions_path, params: { coffee_conversion: { from_state: "cherry", weighed_at: Time.current, input_gross_weight: "100", estimated_yield_percent: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Lugar debe existir").or include("Lugar no puede estar en blanco")
    expect(response.body).to include("Rendimiento estimado (%) no es un número")

    get new_sales_coffee_conversion_path(from_state: "cherry")
    expect(page.at_css("#coffee_conversion_estimated_yield_percent")["value"]).to eq("37.95")
    SiteSetting.create!(business_name: "Rey David", cherry_yield_percent: 40)
    get new_sales_coffee_conversion_path(from_state: "cherry")
    expect(page.at_css("#coffee_conversion_estimated_yield_percent")["value"]).to eq("40.0")
  end

  it "says in Spanish what is missing" do
    post sales_coffee_conversions_path, params: { coffee_conversion: { from_state: "wet_parchment", weighed_at: "", input_gross_weight: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Pesado el no puede estar en blanco")
  end

  it "opens the detail of each card from the summary, and the kardex filtered by its state" do
    get sales_root_path
    expect(card("total")["href"]).to eq(sales_stock_state_path("total"))
    %w[cherry wet_parchment dry_parchment].each do |state|
      expect(card(state)["href"]).to eq(sales_stock_state_path(state))
    end

    get sales_stock_path(coffee_state: "wet_parchment")
    expect(page.css("#stock-ledger tbody tr").map { it.text.squish }).to all(include("Pergamino húmedo"))
  end

  it "lets only who reads Comercialización see them, and only who creates weigh" do
    reader = create(:user).tap { create(:permission, user: it, module_key: "sales", can_read: true) }
    sign_in reader
    get sales_coffee_conversions_path
    expect(response).to have_http_status(:ok)
    post sales_coffee_conversions_path, params: { coffee_conversion: { from_state: "wet_parchment", weighed_at: Time.current, input_gross_weight: "1" } }
    expect(CoffeeConversion.count).to eq(0)
  end
end
