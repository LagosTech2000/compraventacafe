require "rails_helper"

# Developments quoted apart (Fernando, 2026-11-15): one that is off exists
# for nobody but the user who exports the data; on, it is a tab like any.
RSpec.describe PaidFeature do
  let(:admin) { create(:user, :admin) }
  let(:exporter) { make_data_exporter(create(:user, :admin)) }
  let(:clerk) { create(:user).tap { create(:permission, user: it, module_key: "finance", submodule_key: "owner_loans", can_read: true) } }

  before { Current.reset }

  it "keeps the owners' loans closed to everyone but the data exporter until turned on" do
    expect(admin.can?("finance.owner_loans", :read)).to be(false)
    expect(clerk.can?("finance.owner_loans", :read)).to be(false)
    expect(clerk.can?("finance", :read)).to be(false)
    expect(exporter.can?("finance.owner_loans", :create)).to be(true)
    expect(AppModule.offered_submodules("finance", user: admin)).not_to include("owner_loans")

    described_class.ensure_all!.find { it.key == "owner_loans" }.update!(enabled: true)
    Current.reset
    expect(admin.can?("finance.owner_loans", :read)).to be(true)
    expect(clerk.can?("finance.owner_loans", :read)).to be(true)
    expect(clerk.can?("finance.owner_loans", :create)).to be(false)
    expect(AppModule.offered_submodules("finance", user: admin)).to include("owner_loans")
  end

  it "values each development by its hours at the hourly rate, and keeps who turned it on" do
    ControlSetting.current.update!(hourly_rate: 120)
    fingerprints = described_class.ensure_all!.find { it.key == "fingerprints" }
    expect(fingerprints.suggested_value).to eq(40 * 120)
    Current.session = create(:session, user: exporter) rescue nil
    fingerprints.update!(enabled: true, agreed_price: 2_500)
    expect(fingerprints).to have_attributes(agreed_price: 2_500)
    expect(fingerprints.enabled_at).to be_present
  end
end
