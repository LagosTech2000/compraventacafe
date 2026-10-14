require "rails_helper"

# Every menu, the home page tiles and the permission screens list the
# modules in AppModule::KEYS order: Administración last (Fernando, 2026-10-13).
RSpec.describe AppModule do
  it "lists Administración last" do
    expect(AppModule::KEYS.last).to eq("administration")
  end
end
