require "rails_helper"

RSpec.describe CoffeeConversionPolicy do
  def user_with(**flags)
    create(:user).tap { |user| create(:permission, user:, module_key: "sales", can_read: true, **flags) }.reload
  end

  let(:in_process) { create(:coffee_conversion) }
  let(:finished) { create(:coffee_conversion, :finished) }

  it "weighs with create, enters the result with update, voids and takes results off with delete" do
    expect(described_class.new(user_with, in_process)).to permit_actions(%i[index show]).and forbid_actions(%i[create finish void reopen])
    expect(described_class.new(user_with(can_create: true), CoffeeConversion)).to permit_actions(%i[new create])
    expect(described_class.new(user_with(can_update: true), in_process)).to permit_actions(%i[finish])
    expect(described_class.new(user_with(can_update: true), finished)).to forbid_actions(%i[finish])
    remover = user_with(can_destroy: true)
    expect(described_class.new(remover, in_process)).to permit_actions(%i[void]).and forbid_actions(%i[reopen destroy])
    expect(described_class.new(remover, finished)).to permit_actions(%i[reopen]).and forbid_actions(%i[void])
    expect(described_class.new(create(:user, :admin), finished)).to forbid_actions(%i[edit update destroy])
  end
end
