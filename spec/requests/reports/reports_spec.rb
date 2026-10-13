require "rails_helper"

RSpec.describe "Reports" do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "renders every report, detailed and grouped every way, with its charts, next page and CSV" do
    DemoData.new(admin).load
    Report.catalog.each do |report|
      Rails.cache.clear # the CSV and charts limits are per minute; this walks every report at once
      get reports_report_path(report.key, period: "all")
      expect(response).to have_http_status(:ok), "#{report.key}: #{response.status}"

      get reports_report_charts_path(report.key, period: "all")
      expect(response).to have_http_status(:ok), "#{report.key} charts"

      report.groupings.each do |grouping|
        get reports_report_path(report.key, period: "this_season", group: grouping.key)
        expect(response).to have_http_status(:ok), "#{report.key} by #{grouping.key}"
        get reports_report_charts_path(report.key, period: "this_season", group: grouping.key)
        expect(response).to have_http_status(:ok)
      end

      get reports_report_path(report.key, period: "all", page: 2, format: :turbo_stream)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")

      get reports_report_path(report.key, period: "all", format: :csv)
      expect(response.media_type).to eq("text/csv")
    end
  end
end

RSpec.describe "Reports access and tools" do
  def reader(*module_keys)
    create(:user).tap do |user|
      module_keys.each { |key| create(:permission, user:, module_key: key, can_read: true) }
    end
  end

  it "lists only the reports the user may see, and refuses the others" do
    sign_in reader("reports", "trading")
    get reports_root_path

    options = Nokogiri::HTML(response.body).css("#report_type option").map(&:text)
    expect(options).to eq([ "Compras", "Facturas", "Productores" ])
    presets = Nokogiri::HTML(response.body).css("#report_preset option").map(&:text)
    expect(presets).to include("Compras sin facturar")
    expect(presets).not_to include("Préstamos vencidos")

    get reports_report_path("loans")
    expect(response).to redirect_to(root_path)
  end

  it "explains when there is no report to see" do
    sign_in reader("reports")
    get reports_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No tienes acceso a ningún reporte")
  end

  it "loads the next page as a stream that appends rows and moves the button" do
    sign_in create(:user, :admin)
    producer = create(:producer)
    create_list(:purchase, 51, producer:)

    get reports_report_path("purchases")
    expect(Nokogiri::HTML(response.body).css("#report-rows tr").size).to eq(50)
    more = Nokogiri::HTML(response.body).at_css("#report-more a")
    expect(more["data-infinite-scroll-url-value"]).to include("page=2", "format=turbo_stream")

    get more["data-infinite-scroll-url-value"]
    streams = Nokogiri::HTML(response.body).css("turbo-stream").map { |stream| [ stream["action"], stream["target"] ] }
    expect(streams).to include([ "append", "report-rows" ], [ "append", "report-cards" ], [ "replace", "report-more" ])
    expect(response.body).to include("Son todos: 51 registros.")
  end

  it "exports every row to a CSV that Excel opens with accents" do
    sign_in create(:user, :admin)
    producer = create(:producer, person: create(:person, first_names: "Íngrid", last_names: "Peña"))
    create(:purchase, producer:)

    get reports_report_path("purchases", format: :csv)
    body = response.body.force_encoding("UTF-8")
    expect(body).to start_with("﻿Fecha y hora,Productor,")
    expect(body).to include("Íngrid Peña", "4120.9", "Sin facturar")
    expect(response.headers["Content-Disposition"]).to include("reporte-compras-")
  end

  it "saves filters with a name, keeps only what the report knows, and removes them" do
    user = create(:user, :admin)
    sign_in user
    get new_reports_saved_report_path(report_key: "purchases", filters: { period: "this_season", group: "zone" }), headers: { "Turbo-Frame" => "modal" }
    expect(response.body).to include("saved_report[params][group]")

    post reports_saved_reports_path, params: { saved_report: { name: "Zonas", report_key: "purchases",
                                                               params: { period: "this_season", group: "zone", evil: "x", page: "4" } } }
    saved = user.saved_reports.sole
    expect(saved.params).to eq("period" => "this_season", "group" => "zone")

    post reports_saved_reports_path, params: { saved_report: { name: "zonas", report_key: "purchases", params: {} } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("ya lo usas en otro filtro guardado")

    get reports_report_path("purchases")
    expect(Nokogiri::HTML(response.body).css("#saved_report option").map(&:text)).to include("Zonas")

    delete reports_saved_report_path(saved)
    expect(SavedReport.count).to eq(0)
  end

  it "does not show or remove another user's saved filters" do
    saved = SavedReport.create!(user: create(:user, :admin), name: "Ajeno", report_key: "purchases", params: {})
    sign_in create(:user, :admin)

    get reports_report_path("purchases")
    expect(response.body).not_to include("Ajeno")
    delete reports_saved_report_path(saved)
    expect(SavedReport.exists?(saved.id)).to be(true)
  end
end
