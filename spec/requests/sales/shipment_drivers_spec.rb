require "rails_helper"

# A shipment's drivers (Fernando, 2026-11-23): the staff of the roles
# «Chofer» or «Conductor» and the ones marked «Maneja»; nobody else.
RSpec.describe "Shipment drivers" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)

  it "offers only who drives, and refuses anybody else" do
    chofer = create(:staff_member, role: create(:staff_role, name: "Chofer"))
    marked = create(:staff_member, :driver, role: create(:staff_role, name: "CEO"))
    clerk = create(:staff_member, role: create(:staff_role, name: "Contador"))

    sign_in admin
    get new_sales_shipment_path
    offered = page.css("select#shipment_driver_id option").map { it["value"].to_i }
    expect(offered).to include(chofer.id, marked.id)
    expect(offered).not_to include(clerk.id)

    shipment = build(:shipment, driver: clerk, driver_name: nil, carrier: nil)
    expect(shipment).not_to be_valid
    expect(shipment.errors.full_messages.to_sentence).to include("no maneja")
    expect(build(:shipment, driver: chofer, driver_name: nil, carrier: nil)).to be_valid
  end
end
