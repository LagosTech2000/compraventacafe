require "rails_helper"

# «Fincas propias» (Fernando, 2026-10-18): the farm lists filter by whose farm it is.
RSpec.describe "Farm owner filter" do
  let(:admin) { create(:user, :admin) }

  before do
    create(:farm, name: "Finca del negocio")
    create(:farm, name: "Finca de Ana", producer: create(:producer))
    sign_in admin
  end

  def names = Nokogiri::HTML(response.body).css("table tbody tr td:first-child").map { it.text.strip }

  it "shows the business's own farms, the producers', or all" do
    get farms_farms_path(owner: "business")
    expect(names).to eq([ "Finca del negocio" ])

    get farms_farms_path(owner: "producers")
    expect(names).to all(start_with("Finca de Ana"))
    expect(names.size).to eq(1)

    get farms_farms_path
    expect(names.size).to eq(2)
  end

  it "filters Administración → Fincas the same way" do
    get administration_farms_path(owner: "business")

    expect(response.body).to include("Finca del negocio")
    expect(response.body).not_to include("Finca de Ana")
  end

  it "finds farms by their producer's name, every word and without accents (Fernando, 2026-11-13)" do
    create(:farm, name: "La Cumbre", producer: create(:producer, person: create(:person, first_names: "José Ángel", last_names: "Martínez")))

    get farms_farms_path(q: "jose martinez")
    expect(names).to eq([ "La Cumbre · José Ángel Martínez" ])
    get administration_farms_path(q: "Martínez")
    expect(response.body).to include("La Cumbre")
    expect(response.body).not_to include("Finca del negocio")

    get farms_farms_path(q: "negocio")
    expect(names).to eq([ "Finca del negocio" ])
  end
end
