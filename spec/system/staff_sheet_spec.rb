require "rails_helper"

# The fortnight of the payroll sheet on screen (staff_sheet_controller.js):
# days cycle — → 1 → ½, the days, earned and total follow the Excel's rule,
# and the attendance is saved.
RSpec.describe "Planilla interna sheet", type: :system do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :admin) }

  before do
    travel_to(Time.zone.local(2026, 10, 20, 10))
    sign_in_as(user)
  end

  after { travel_back }

  it "marks days, recalculates like the Excel and saves the attendance" do
    role = create(:staff_role, name: "Cargador", salary: 12_000, pay_frequency: "biweekly")
    member = create(:staff_member, role:, starts_on: Date.new(2026, 10, 1), person: create(:person, :collaborator, first_names: "Inman", last_names: "Demo"))
    create(:staff_advance, member:, given_on: Date.new(2026, 10, 4), amount: 500, money_account: create(:money_account))

    visit finance_staff_sheet_path(month: "2026-10", half: 1)
    row = "#sheet_staff_member_#{member.id}"
    within(row) { click_button "Toda la quincena" }
    # Whole fortnight: 15 days → 12,000 ÷ 30 × 15 = 6,000 − 500
    expect(page).to have_css("#{row} [data-staff-sheet-target='days']", text: "15")
    expect(page).to have_css("#{row} [data-staff-sheet-target='total']", text: "L 5,500.00")

    # Two days off (9 and 10): 13 days → 5,200 − 500 = 4,700, like the Excel.
    [ 9, 10 ].each do |day|
      label = "#{member.full_name}, #{I18n.l(Date.new(2026, 10, day), format: :long)}"
      2.times { find("button[aria-label='#{label}']").click } # 1 → ½ → —
    end
    expect(page).to have_css("#{row} [data-staff-sheet-target='days']", text: "13")
    expect(page).to have_css("#{row} [data-staff-sheet-target='total']", text: "L 4,700.00")

    click_button "Guardar asistencia"
    expect(page).to have_text("Asistencia guardada.")
    expect(member.attendances.count).to eq(13)
  end
end
