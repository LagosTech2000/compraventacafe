require "rails_helper"

# The payroll lists say how many people are in each payroll (its active
# members), in the table and on the phone's cards, and sort by it.
RSpec.describe "People in the payroll lists" do
  let(:admin) { create(:user, :admin) }

  it "counts the active members of each payroll and sorts by them" do
    farm = create(:farm)
    big = create(:payroll, farm:, name: "Corte grande")
    small = create(:payroll, farm:, name: "Limpia")
    empty = create(:payroll, farm:, name: "Sin gente")
    create_list(:payroll_member, 3, payroll: big)
    create(:payroll_member, payroll: small)
    create(:payroll_member, payroll: small, active: false)
    sign_in admin

    [ farms_payrolls_path, farms_farm_path(farm) ].each do |path|
      get path
      page = Nokogiri::HTML(response.body)
      counts = [ big, small, empty ].map { |payroll| page.at_css("##{ActionView::RecordIdentifier.dom_id(payroll)} [data-payroll-people]").text }
      expect(counts).to eq(%w[3 1 0])
      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(big, :card)}").text).to include("3 personas")
      expect(page.at_css("##{ActionView::RecordIdentifier.dom_id(empty, :card)}").text).to include("Sin personas")
    end

    get farms_payrolls_path(sort: "people", dir: "desc")
    names = Nokogiri::HTML(response.body).css("tbody tr td:first-child").map { |cell| cell.text.squish }
    expect(names).to eq([ "Corte grande", "Limpia", "Sin gente" ])
  end

  it "says how many people each attendance grid has" do
    daily = create(:payroll)
    create_list(:payroll_member, 3, payroll: daily)
    harvest = create(:payroll, kind: "harvest")
    create(:payroll_member, payroll: harvest, daily_wage_override: 300) # caporal: paid by day
    create_list(:payroll_member, 2, payroll: harvest)
    sign_in admin

    get farms_payroll_timesheet_path(daily)
    expect(Nokogiri::HTML(response.body).css("[data-timesheet-people]").map(&:text)).to eq([ "3" ])

    get farms_payroll_timesheet_path(harvest)
    counts = Nokogiri::HTML(response.body).css("[data-timesheet-people]")
    expect(counts.map(&:text)).to eq([ "2", "1" ]) # cutters, then the foremen paid by day
    expect(counts.first["title"]).to eq("2 personas")
  end
end
