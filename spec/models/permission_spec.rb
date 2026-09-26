require "rails_helper"

RSpec.describe Permission do
  it "requires a known module key" do
    permission = build(:permission, module_key: "payroll")
    expect(permission).not_to be_valid
    expect(permission.errors[:module_key]).to be_present
  end

  it "allows one row per user and module" do
    existing = create(:permission, module_key: "farms")
    duplicate = build(:permission, user: existing.user, module_key: "farms")
    expect(duplicate).not_to be_valid
  end

  it "enforces uniqueness in the database too" do
    existing = create(:permission, module_key: "farms")
    duplicate = build(:permission, user: existing.user, module_key: "farms")
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
