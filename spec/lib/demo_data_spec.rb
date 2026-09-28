require "rails_helper"

RSpec.describe DemoData do
  it "loads fictitious data, leaving today's purchases uninvoiced" do
    described_class.new(create(:user, :admin)).load
    expect(Producer.count).to eq(15)
    expect(Person.pluck(:last_names)).to all(start_with("Demo"))
    expect(Purchase.on(Time.zone.today).uninvoiced.count).to eq(Purchase.on(Time.zone.today).count)
    expect(Invoice.count).to be_positive
  end
end
