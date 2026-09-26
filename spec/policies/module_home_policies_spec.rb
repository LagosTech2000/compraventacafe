require "rails_helper"

# Every module/action combination, allowed and denied, through the policies.
RSpec.describe "Module home policies" do
  rules = { "read" => %i[index show], "create" => %i[new create], "update" => %i[edit update], "destroy" => %i[destroy] }

  AppModule::KEYS.each do |key|
    describe "#{key.camelize}::HomePolicy" do
      subject { "#{key.camelize}::HomePolicy".constantize.new(user, :home) }

      AppModule::ACTIONS.each do |action|
        context "with only #{action}" do
          let(:user) { create(:user).tap { |u| create(:permission, user: u, module_key: key, "can_#{action}": true) }.reload }

          it { is_expected.to permit_actions(rules[action]) }
          it { is_expected.to forbid_actions(rules.except(action).values.flatten) }
        end
      end

      context "with no permissions" do
        let(:user) { create(:user) }

        it { is_expected.to forbid_all_actions }
      end

      context "with every flag set on another module" do
        let(:other) { (AppModule::KEYS - [ key ]).first }
        let(:user) do
          create(:user).tap { |u| create(:permission, user: u, module_key: other, can_read: true, can_create: true, can_update: true, can_destroy: true) }.reload
        end

        it { is_expected.to forbid_all_actions }
      end

      context "as an admin" do
        let(:user) { create(:user, :admin) }

        it { is_expected.to permit_all_actions }
      end

      context "without a user" do
        let(:user) { nil }

        it { is_expected.to forbid_all_actions }
      end
    end
  end
end
