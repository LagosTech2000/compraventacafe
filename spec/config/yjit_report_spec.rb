require "rails_helper"

# The boot log says whether YJIT is on (to check it on Render). It must be
# written after Rails turns YJIT on, in its last boot step: before, it
# said "not available" even when it was on.
RSpec.describe "YJIT in the boot log" do
  it "is reported after Rails turns YJIT on" do
    names = Rails.application.initializers.tsort_each.map(&:name)
    expect(names.index(:report_yjit)).to be > names.index(:enable_yjit)
  end
end
