require "rails_helper"

RSpec.describe PersonPolicy do
  subject { described_class.new(user, Person.new) }

  rules = { "read" => %i[index show], "create" => %i[new create], "update" => %i[edit update], "destroy" => %i[destroy] }

  AppModule::ACTIONS.each do |action|
    context "with only administration #{action}" do
      let(:user) { create(:user).tap { |u| create(:permission, user: u, module_key: "administration", "can_#{action}": true) }.reload }

      it { is_expected.to permit_actions(rules[action]) }
      it { is_expected.to forbid_actions(rules.except(action).values.flatten) }
    end
  end

  context "with every flag on another module" do
    let(:user) { create(:user).tap { |u| create(:permission, user: u, module_key: "trading", can_read: true, can_create: true, can_update: true, can_destroy: true) }.reload }

    it { is_expected.to forbid_all_actions }
  end

  describe "scope" do
    before { create(:person) }

    it "returns everyone to a reader" do
      user = create(:user).tap { |u| create(:permission, user: u, module_key: "administration", can_read: true) }.reload
      expect(described_class::Scope.new(user, Person).resolve.count).to eq(1)
    end

    it "returns nobody to a non-reader" do
      expect(described_class::Scope.new(create(:user), Person).resolve).to be_empty
    end
  end
end
