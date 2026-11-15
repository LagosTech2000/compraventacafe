require "rails_helper"

RSpec.describe Permission do
  it "requires a known module key" do
    permission = build(:permission, module_key: "payroll", submodule_key: "purchases")
    expect(permission).not_to be_valid
    expect(permission.errors[:module_key]).to be_present
  end

  it "requires a submodule of its module" do
    expect(build(:permission, module_key: "trading", submodule_key: "invoices")).to be_valid
    expect(build(:permission, module_key: "trading", submodule_key: "payrolls")).not_to be_valid
    expect(build(:permission, module_key: "trading", submodule_key: nil).tap(&:validate).errors[:submodule_key]).to be_present
  end

  it "allows one row per user, module and submodule" do
    existing = create(:permission, module_key: "farms", submodule_key: "payrolls")
    expect(build(:permission, user: existing.user, module_key: "farms", submodule_key: "payrolls")).not_to be_valid
    expect(build(:permission, user: existing.user, module_key: "farms", submodule_key: "farms")).to be_valid
  end

  it "enforces uniqueness in the database too" do
    existing = create(:permission, module_key: "farms", submodule_key: "payrolls")
    duplicate = build(:permission, user: existing.user, module_key: "farms", submodule_key: "payrolls")
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "is named by its module and tab, or by the module alone when it has one tab" do
    expect(build(:permission, module_key: "trading", submodule_key: "invoices").human_name).to eq("Compra de café › Facturas")
    expect(build(:permission, module_key: "reports", submodule_key: "reports").human_name).to eq("Reportería")
  end

  it "the factory without a submodule grants the whole module, a row per submodule" do
    user = create(:user)
    create(:permission, user:, module_key: "trading", can_read: true)
    expect(user.permissions.pluck(:submodule_key)).to match_array(AppModule.submodules("trading"))
    expect(user.permissions).to all(have_attributes(can_read: true, can_create: false))
  end
end
