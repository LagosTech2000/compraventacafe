require "rails_helper"

# A person's fingerprint (Fernando, 2026-11-14): the reader's template,
# encrypted, with the person's consent; one per finger.
RSpec.describe Fingerprint do
  it "keeps the template encrypted and gives it back as the bridge sent it" do
    template = Base64.strict_encode64(Random.bytes(800))
    fingerprint = create(:fingerprint, template:)

    expect(fingerprint.reload.template).to eq(template)
    expect(fingerprint.template_ciphertext).not_to include(template)
  end

  it "rejects a template that is not base64, empty or too big" do
    expect(build(:fingerprint, template: "no es base64!")).to be_invalid
    expect(build(:fingerprint, template: "")).to be_invalid
    expect(build(:fingerprint, template: Base64.strict_encode64(Random.bytes(Fingerprint::MAX_TEMPLATE_BYTES + 1)))).to be_invalid
  end

  it "takes each finger once per person, and only the ten fingers" do
    fingerprint = create(:fingerprint)
    expect(build(:fingerprint, person: fingerprint.person)).to be_invalid
    expect(build(:fingerprint, person: fingerprint.person, finger: "left_thumb")).to be_valid
    expect(build(:fingerprint, finger: "toe")).to be_invalid
  end

  it "needs the person's consent" do
    expect(build(:fingerprint, consented_at: nil)).to be_invalid
  end

  it "tells the bridges to load the templates again when it changes" do
    expect { create(:fingerprint) }.to have_broadcasted_to(Fingerprint::BRIDGES_STREAM).with(type: "templates_changed")
  end

  it "is audited without its template, and goes with its person" do
    fingerprint = create(:fingerprint)
    event = AuditEvent.where(auditable: fingerprint).sole
    expect(event.changeset["template_ciphertext"]).to eq([ nil, AuditEvent::FILTERED ])
    expect(event.auditable_label).to eq("#{fingerprint.person.full_name} · Índice derecho")

    expect { fingerprint.person.destroy! }.to change(described_class, :count).by(-1)
  end
end
