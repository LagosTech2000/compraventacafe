require "rails_helper"

# A producer without a zone takes the zone of the purchase registered for
# them (Fernando, 2026-10-18).
RSpec.describe Purchase do
  let(:zone) { create(:zone, name: "El Rosario") }

  it "gives its zone to a producer without one, audited as the person's change" do
    producer = create(:producer)

    purchase = create(:purchase, producer:, zone:)

    expect(producer.person.reload.zone).to eq(zone)
    expect(purchase.zone_given_to_producer).to eq(zone)
    expect(AuditEvent.where(auditable_type: "Person", auditable_id: producer.person_id, action: "update").last.changeset).to include("zone_id")
  end

  it "never replaces the producer's zone, and does nothing without a zone of its own" do
    other = create(:zone, name: "Otra")
    producer = create(:producer, person: create(:person, zone: other))
    create(:purchase, producer:, zone:)
    expect(producer.person.reload.zone).to eq(other)

    without = create(:producer)
    purchase = create(:purchase, producer: without, zone: nil)
    expect(without.person.reload.zone).to be_nil
    expect(purchase.zone_given_to_producer).to be_nil
  end

  it "only when it is registered, not when it is edited" do
    producer = create(:producer)
    purchase = create(:purchase, producer:, zone: nil)

    purchase.update!(zone:)

    expect(producer.person.reload.zone).to be_nil
  end
end
