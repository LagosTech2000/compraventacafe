require "rails_helper"

RSpec.describe UserPolicy do
  subject { described_class.new(user, User.new) }

  context "as an active admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show new create edit update edit_password reset_password]) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context "as a user with every administration flag" do
    let(:user) do
      create(:user).tap { |u| create(:permission, user: u, module_key: "administration", can_read: true, can_create: true, can_update: true, can_destroy: true) }.reload
    end

    it { is_expected.to forbid_all_actions }
  end

  context "as an inactive admin" do
    let(:user) do
      create(:user, :admin)
      create(:user, :admin, :inactive)
    end

    it { is_expected.to forbid_all_actions }
  end
end
