require "rails_helper"

# Converting coffee from Comercialización: weigh what goes in, enter what came
# out; the stock, its cards and the kardex follow, in gross, net and QQ.
RSpec.describe "Coffee conversions" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)
  def card(key) = page.at_css("[data-coffee-state=#{key}]")
  def card_values(key) = card(key).css("dd").map { it.text.squish }

  before do
    create(:purchase, gross_weight: 2_000) # 973.63 lb net of wet parchment
    sign_in admin
  end

  it "weighs what goes in, keeps it in process, then enters what came out" do
    get new_sales_coffee_conversion_path(from_state: "wet_parchment")
    expect(response).to have_http_status(:ok)
    expect(page.at_css("input[type=radio][value=wet_parchment][checked]")).to be_present

    post sales_coffee_conversions_path, params: { coffee_conversion: { from_state: "wet_parchment", weighed_at: Time.current.change(sec: 0),
                                                                         input_gross_weight: "1000", observations: "Patio 1" } }
    conversion = CoffeeConversion.sole
    expect(response).to redirect_to(sales_coffee_conversion_path(conversion))
    expect(conversion).to have_attributes(input_net_weight: BigDecimal("486.82"), created_by: admin, status: "in_process")
    expect(AuditEvent.where(auditable: conversion, action: "create")).to exist

    get sales_stock_path
    expect(card_values("wet_parchment")).to eq([ "1,000.00 lb", "486.81 lb", "3.89" ])
    expect(card_values("in_process")).to eq([ "1,000.00 lb", "486.82 lb", "3.89" ])
    expect(card("in_process")["href"]).to eq(sales_coffee_conversions_path(status: "in_process"))

    get edit_sales_coffee_conversion_result_path(conversion)
    expect(response).to have_http_status(:ok)
    patch sales_coffee_conversion_result_path(conversion), params: { coffee_conversion: { finished_at: Time.current.change(sec: 0),
                                                                                           output_gross_weight: "600", output_sacks: "4", output_humidity_percent: "12",
                                                                                           output_damage_percent: "", lock_version: conversion.lock_version } }
    expect(conversion.reload).to have_attributes(status: "finished", output_net_weight: BigDecimal("524.48"), output_damage_percent: 0, finished_by: admin)

    get sales_stock_path
    expect(card_values("dry_parchment")).to eq([ "600.00 lb", "524.48 lb", "4.20" ])
    expect(card("in_process")).to be_nil
    rows = page.css("#stock-ledger tbody tr").map { it.text.squish }
    expect(rows).to include(a_string_including("De conversión", "Pergamino seco", "+600.00", "+524.48", "+4.20"),
                            a_string_including("A conversión", "Pergamino húmedo", "−1,000.00", "−486.82", "−3.89"))

    get sales_coffee_conversion_path(conversion)
    expect(page.at_css("[data-conversion-side=output]").text.squish).to include("600.00 lb", "524.48 lb", "4.20", "Sacos que salieron4", "12.00")
    expect(page.at_css("[data-conversion-comparison]").text.squish).to include("486.82 lb", "524.48 lb", "37.66 lb más", "7.7 %")
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

  it "says in Spanish what is missing" do
    post sales_coffee_conversions_path, params: { coffee_conversion: { from_state: "wet_parchment", weighed_at: "", input_gross_weight: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Pesado el no puede estar en blanco")
  end

  it "opens the kardex of each card from the summary, filtered by its state" do
    get sales_root_path
    expect(card("total")["href"]).to start_with(sales_stock_path)
    %w[cherry wet_parchment dry_parchment].each do |state|
      expect(card(state)["href"]).to eq(sales_stock_path(coffee_state: state, anchor: "stock-ledger-title"))
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
