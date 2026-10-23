require "rails_helper"

RSpec.describe "Private documents policies" do
  def user_with(module_key, **flags)
    create(:user).tap { |user| create(:permission, user:, module_key:, **flags) }.reload
  end

  let(:admin) { create(:user, :admin) }
  let(:document) { PrivateDocument.fetch("promissory_note") }

  describe PrivateDocumentPolicy do
    it "lets only admins see and edit the documents, and nobody add or remove one" do
      expect(described_class.new(admin, document)).to permit_actions(%i[index show edit update])
      expect(described_class.new(admin, document)).to forbid_actions(%i[new create destroy])

      manager = user_with("administration", can_read: true, can_create: true, can_update: true, can_destroy: true)
      expect(described_class.new(manager, document)).to forbid_actions(%i[index show edit update create destroy])
      expect(described_class.new(create(:user, :admin, :inactive), document)).to forbid_actions(%i[index show update])
    end
  end

  describe PrivateDocumentPrintPolicy do
    let(:print) { PrivateDocumentPrint.new }

    it "lets whoever lends print, and only admins see who printed and when" do
      lender = user_with("loans", can_read: true, can_create: true)
      expect(described_class.new(lender, print)).to permit_actions(%i[new create show])
      expect(described_class.new(lender, print)).to forbid_actions(%i[history index update destroy])

      reader = user_with("loans", can_read: true)
      expect(described_class.new(reader, print)).to forbid_actions(%i[new create show history])

      expect(described_class.new(admin, print)).to permit_actions(%i[new create show history])
    end
  end
end
