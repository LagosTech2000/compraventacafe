require "rails_helper"

# «Cierre del día» (Fernando, 2026-11-18): an administrator closes a day for
# the whole business after its checklist; only the main user reopens the
# latest one, with a reason.
RSpec.describe "Business day closes" do
  let(:admin) { create(:user, :admin) }
  let(:yesterday) { 1.day.ago.to_date }

  def page = Nokogiri::HTML(response.body)

  it "shows the day's checklist, asks to confirm what is missing, closes and locks" do
    create(:purchase, purchased_at: yesterday.in_time_zone.change(hour: 9))
    sign_in admin

    get administration_day_closes_path(day: yesterday)
    expect(page.at_css("[data-close-checklist] [data-daily-check='uninvoiced']").text).to include("1 de hoy sin facturar")
    expect(page.at_css("input#reviewed")).to be_present

    post administration_day_closes_path, params: { business_day_close: { closed_on: yesterday } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("marca que lo revisaste")
    expect(BusinessDayClose.count).to eq(0)

    post administration_day_closes_path, params: { business_day_close: { closed_on: yesterday, notes: "Sin facturar una" }, reviewed: "1" }
    expect(response).to redirect_to(administration_day_closes_path)
    expect(BusinessDayClose.locked_through).to eq(yesterday)
    expect(BusinessDayClose.last).to have_attributes(closed_by: admin, notes: "Sin facturar una")

    get administration_day_closes_path
    expect(page.at_css("[data-locked-through]").text).to include(I18n.l(yesterday, format: :long))
    post administration_day_closes_path, params: { business_day_close: { closed_on: yesterday - 1 }, reviewed: "1" }
    expect(response.body).to include("ya está cerrado")

    post trading_purchases_path, params: { purchase: attributes_for(:purchase).merge(producer_id: create(:producer).id, purchased_at: yesterday.in_time_zone.change(hour: 15), hauler_choice: "none") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("está cerrado")
  end

  it "lets only the main user reopen the latest close, with a reason" do
    close = BusinessDayClose.create!(closed_on: yesterday, closed_by: admin)
    sign_in admin
    get administration_day_closes_path
    expect(page.css("form[action='#{reopen_administration_day_close_path(close)}']")).to be_empty
    patch reopen_administration_day_close_path(close), params: { business_day_close: { reopen_reason: "x" } }
    expect(close.reload).not_to be_reopened

    main = make_data_exporter(create(:user, :admin))
    sign_in main
    patch reopen_administration_day_close_path(close), params: { business_day_close: { reopen_reason: "" } }
    expect(close.reload).not_to be_reopened
    patch reopen_administration_day_close_path(close), params: { business_day_close: { reopen_reason: "Faltó una compra" } }
    expect(close.reload).to have_attributes(reopened_by: main, reopen_reason: "Faltó una compra")
    expect(BusinessDayClose.locked_through).to be_nil
  end

  it "is for administrators only, and the Inicio links it" do
    sign_in admin
    get root_path
    expect(page.at_css("#dashboard-daily-check a[href='#{administration_day_closes_path}']")).to be_present

    sign_in create(:user).tap { create(:permission, user: it, module_key: "administration", can_read: true, can_create: true) }
    get administration_day_closes_path
    expect(response).to redirect_to(root_path)
  end
end
