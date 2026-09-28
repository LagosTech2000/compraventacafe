require "rails_helper"

RSpec.describe DashboardPolicy do
  it "lets any signed-in user see the home page" do
    expect(described_class.new(create(:user), :dashboard)).to permit_action(:show)
  end

  it "rejects a missing user" do
    expect(described_class.new(nil, :dashboard)).to forbid_action(:show)
  end
end
