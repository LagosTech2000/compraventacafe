require "rails_helper"

RSpec.describe ReportPolicy do
  def user_with(*module_keys)
    create(:user).tap do |user|
      module_keys.each { |key| create(:permission, user:, module_key: key, can_read: true) }
    end.reload
  end

  it "needs reading reports and the module the data comes from" do
    expect(described_class.new(user_with("reports", "trading"), PurchasesReport)).to be_show
    expect(described_class.new(user_with("reports"), PurchasesReport)).not_to be_show
    expect(described_class.new(user_with("trading"), PurchasesReport)).not_to be_show
    expect(described_class.new(user_with("reports", "trading"), LoansReport)).not_to be_show
  end

  it "needs every module a cross-module report reads" do
    expect(described_class.new(user_with("reports", "trading", "loans"), CashMovementsReport)).not_to be_show
    expect(described_class.new(user_with("reports", "trading", "loans", "farms"), CashMovementsReport)).to be_show
    expect(described_class.new(create(:user, :admin), PeopleReport)).to be_show
  end
end

RSpec.describe SavedReportPolicy do
  it "lets each user remove only their own saved filters" do
    owner = create(:user, :admin)
    other = create(:user, :admin)
    saved = SavedReport.create!(user: owner, name: "Mío", report_key: "purchases", params: {})

    expect(described_class.new(owner, saved)).to permit_actions(%i[destroy])
    expect(described_class.new(other, saved)).to forbid_actions(%i[destroy])
    expect(SavedReportPolicy::Scope.new(other, SavedReport).resolve).to be_empty
  end
end
