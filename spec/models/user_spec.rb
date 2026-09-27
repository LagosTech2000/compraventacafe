require "rails_helper"

RSpec.describe User do
  it "requires a full name and squishes its spaces" do
    expect(build(:user, name: "")).not_to be_valid
    expect(create(:user, name: "  Ana   María  Paz ").name).to eq("Ana María Paz")
  end

  it "normalizes the email address" do
    user = create(:user, email_address: "  Ana@Example.COM ")
    expect(user.email_address).to eq("ana@example.com")
  end

  describe "#can?" do
    AppModule::KEYS.each do |key|
      AppModule::ACTIONS.each do |action|
        context "#{key}/#{action}" do
          it "allows when the flag is set" do
            user = create(:user)
            create(:permission, user: user, module_key: key, "can_#{action}": true)
            expect(user.reload.can?(key, action)).to be(true)
          end

          it "denies when the flag is not set" do
            user = create(:user)
            other_actions = (AppModule::ACTIONS - [ action ]).to_h { |a| [ :"can_#{a}", true ] }
            create(:permission, user: user, module_key: key, **other_actions)
            expect(user.reload.can?(key, action)).to be(false)
          end
        end
      end
    end

    it "denies when there is no permission row" do
      expect(create(:user).can?(:trading, :read)).to be(false)
    end

    it "does not leak permissions across modules" do
      user = create(:user)
      create(:permission, user: user, module_key: "trading", can_read: true)
      expect(user.reload.can?(:farms, :read)).to be(false)
    end

    it "allows everything to an active admin" do
      admin = create(:user, :admin)
      expect(AppModule::KEYS.product(AppModule::ACTIONS).all? { |k, a| admin.can?(k, a) }).to be(true)
    end

    it "denies everything to an inactive user, even an admin with flags" do
      create(:user, :admin) # keeps an active admin around
      user = create(:user, :admin, :inactive)
      create(:permission, user: user, module_key: "trading", can_read: true)
      expect(user.reload.can?(:trading, :read)).to be(false)
    end

    it "rejects unknown modules and actions" do
      user = create(:user)
      expect { user.can?(:payroll, :read) }.to raise_error(ArgumentError)
      expect { user.can?(:trading, :approve) }.to raise_error(ArgumentError)
    end
  end

  describe "last active admin" do
    let!(:admin) { create(:user, :admin) }

    it "cannot be deactivated" do
      expect(admin.update(active: false)).to be(false)
      expect(admin.errors[:base]).to include(I18n.t("activerecord.errors.models.user.last_active_admin"))
    end

    it "cannot lose the admin flag" do
      expect(admin.update(admin: false)).to be(false)
    end

    it "does not count inactive admins as a replacement" do
      create(:user, :admin).update_columns(active: false)
      expect(admin.update(active: false)).to be(false)
    end

    it "can be deactivated when another active admin exists" do
      create(:user, :admin)
      expect(admin.update(active: false)).to be(true)
    end

    it "does not block edits that keep them an active admin" do
      expect(admin.update(email_address: "nuevo@example.com")).to be(true)
    end
  end
end
