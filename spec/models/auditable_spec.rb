require "rails_helper"

RSpec.describe Auditable do
  let(:actor) { create(:user) }

  before { allow(Current).to receive(:user).and_return(actor) }

  it "records who created what, with the values" do
    zone = create(:zone, name: "Buenas Noches")
    event = AuditEvent.where(auditable: zone).sole
    expect(event).to have_attributes(action: "create", user: actor, user_email: actor.email_address, auditable_label: "Buenas Noches")
    expect(event.changeset).to eq("name" => [ nil, "Buenas Noches" ])
  end

  it "records only the fields that changed, before and after" do
    purchase = create(:purchase)
    purchase.update!(price_per_pound: 60)
    event = AuditEvent.where(auditable: purchase, action: "update").sole
    expect(event.changeset.keys).to contain_exactly("price_per_pound", "total")
    expect(event.changeset["price_per_pound"]).to eq([ "58.0", "60.0" ])
  end

  it "skips updates that change nothing" do
    zone = create(:zone)
    expect { zone.update!(name: zone.name) }.not_to change(AuditEvent, :count)
  end

  it "keeps what was deleted readable" do
    person = create(:person, first_names: "Rosa", last_names: "Paz")
    person.destroy!
    event = AuditEvent.find_by!(action: "destroy", auditable_type: "Person")
    expect(event.auditable_label).to eq("Rosa Paz")
    expect(event.changeset["first_names"]).to eq([ "Rosa", nil ])
  end

  it "never stores passwords" do
    user = create(:user)
    user.update!(password: "otra-clave-larga")
    changes = AuditEvent.where(auditable: user).flat_map { |event| event.changeset.to_a }
    expect(changes.to_h["password_digest"]).to eq([ AuditEvent::FILTERED, AuditEvent::FILTERED ])
    expect(AuditEvent.pluck(:changeset).to_s).not_to include("$2a$")
  end

  it "rolls back with the change it describes" do
    expect {
      Zone.transaction do
        create(:zone)
        raise ActiveRecord::Rollback
      end
    }.not_to change(AuditEvent, :count)
  end

  it "records system changes without a user" do
    allow(Current).to receive(:user).and_return(nil)
    create(:zone)
    expect(AuditEvent.last).to have_attributes(user: nil, user_email: nil)
  end

  it "cannot be edited or deleted" do
    event = AuditEvent.where(auditable: create(:zone)).sole
    expect { event.update!(action: "destroy") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "covers exactly the models listed in AuditEvent::AUDITED_TYPES" do
    Rails.application.eager_load!
    audited = ApplicationRecord.descendants.select { |model| model.include?(described_class) }.map(&:name)
    expect(audited).to match_array(AuditEvent::AUDITED_TYPES)
  end
end
