require "rails_helper"

# Merging the same person registered twice (Fernando, 2026-10-14): the
# primary stays, details are chosen field by field, everything of the other
# one moves over, farms with the same name join, and the other is deleted.
RSpec.describe PersonMerge do
  let(:user) { create(:user, :admin) }
  let(:zone) { create(:zone, name: "El Rosario") }
  let(:primary) { create(:person, first_names: "Ana María", last_names: "Zelaya", phone: "99990000") }
  let(:secondary) { create(:person, first_names: "Ana Maria", last_names: "Zelaya", dni: "0801199912345", zone:) }

  before { Current.session = user.sessions.create! }
  after { Current.reset }

  def merge(choices = {}) = described_class.new(primary:, secondary:, choices:)

  it "keeps the primary's details by default, but takes the other's where the primary has none" do
    m = merge
    expect(m.differences).to eq(%w[first_names dni phone zone])
    expect(m.differences.to_h { [ it, m.choice(it) ] }).to eq("first_names" => "primary", "dni" => "secondary", "phone" => "primary", "zone" => "secondary")
    expect(m.save).to be(true)

    expect(primary.reload).to have_attributes(first_names: "Ana María", dni: "0801199912345", phone: "99990000", zone:)
    expect(Person.exists?(secondary.id)).to be(false)
  end

  it "takes each detail from the side chosen, including a unique DNI held by the other" do
    primary.update!(dni: "0801199900000", rtn: "08011999000001")
    expect(merge("first_names" => "secondary", "dni" => "secondary", "phone" => "secondary").save).to be(true)
    expect(primary.reload).to have_attributes(first_names: "Ana Maria", dni: "0801199912345", phone: nil, rtn: "08011999000001")
  end

  it "moves purchases, invoices, farms, loans and payrolls to the primary, joining farms of the same name" do
    kept = create(:producer, person: primary, ihcafe_code: nil)
    other = create(:producer, person: secondary, ihcafe_code: "AB-12-34567", kind: "intermediary")
    loma = create(:farm, producer: kept, name: "La Loma")
    loma_copy = create(:farm, producer: other, name: " la loma ", area_value: 3, area_unit: "manzana", observations: "Cerca del río")
    cerro = create(:farm, producer: other, name: "El Cerro")
    bought = create(:purchase, producer: other, farm: loma_copy)
    invoiced = create(:purchase, producer: other, farm: cerro)
    InvoiceIssuer.new(producer: other, user:, purchase_ids: [ invoiced.id ], payment_status: "pending").call
    invoice = invoiced.reload.invoice
    payroll = create(:payroll, farm: loma_copy)
    loan = create(:loan, person: secondary)
    create(:client, person: secondary)
    create(:collaborator, person: secondary)
    member = create(:payroll_member, payroll: create(:payroll), person: secondary)

    m = merge("kind" => "secondary")
    expect(m.differences).to include("kind", "ihcafe_code")
    expect(m.choice("ihcafe_code")).to eq("secondary")
    expect(m.joining_farms).to eq([ " la loma ".squish ])
    expect(m.summary).to eq(purchases: 2, invoices: 1, farms: 2, loans: 1, payrolls: 1)
    expect(m.gained_roles).to eq(%i[client collaborator])
    expect(m.save).to be(true)

    expect(kept.reload).to have_attributes(kind: "intermediary", ihcafe_code: "AB-12-34567")
    expect(kept.farms.map(&:name)).to eq([ "El Cerro", "La Loma" ])
    expect(Farm.exists?(loma_copy.id)).to be(false)
    expect(loma.reload).to have_attributes(area_value: 3, area_unit: "manzana", observations: "Cerca del río")
    expect([ bought.reload.producer, bought.farm ]).to eq([ kept, loma ])
    expect([ invoiced.reload.producer, invoice.reload.producer ]).to eq([ kept, kept ])
    expect(payroll.reload.farm).to eq(loma)
    expect(loan.reload.person).to eq(primary)
    expect(member.reload.person).to eq(primary)
    expect(primary.reload).to be_client
    expect(primary).to be_collaborator
    expect(Producer.exists?(other.id)).to be(false)

    event = AuditEvent.find_by!(action: "merge")
    expect(event).to have_attributes(auditable_type: "Person", auditable_id: primary.id)
    expect(event.details).to include("merged" => "Ana Maria Zelaya ##{secondary.id}", "farms_joined" => "la loma",
                                     "roles" => "Cliente, Colaborador", "chosen" => a_string_including("DNI", "Tipo"))
    expect(event.details["moved"]).to include("Compras: 2", "Facturas: 1", "Préstamos: 1", "Planillas: 1")
  end

  it "gives the producer to the primary when only the other one is a producer" do
    other = create(:producer, person: secondary)
    create(:purchase, producer: other)
    expect(merge.save).to be(true)
    expect(other.reload.person).to eq(primary)
  end

  it "takes the other's photo when chosen" do
    secondary.update!(photo_upload: uploaded_picture)
    photo = secondary.photo
    m = merge
    expect(m.differences).to include("photo")
    expect(m.choice("photo")).to eq("secondary")
    expect(m.save).to be(true)
    expect(primary.reload.photo).to eq(photo)
  end

  it "does not merge two people in the same payroll, nor a person with itself" do
    payroll = create(:payroll, name: "Limpia")
    [ primary, secondary ].each { create(:collaborator, person: it) }
    create(:payroll_member, payroll:, person: primary)
    create(:payroll_member, payroll:, person: secondary)
    m = merge
    expect(m.save).to be(false)
    expect(m.errors.full_messages).to eq([ "Las dos personas están en la planilla Limpia: quita a una de ella antes de fusionarlas." ])
    expect(Person.exists?(secondary.id)).to be(true)

    same = described_class.new(primary:, secondary: primary)
    expect(same.save).to be(false)
    expect(same.errors.full_messages).to include("Elige a otra persona: no se puede fusionar una persona consigo misma.")
  end

  it "leaves everything as it was when something fails" do
    create(:producer, person: secondary)
    allow(Loan).to receive(:where).and_raise(ActiveRecord::RecordInvalid.new(Person.new.tap { it.errors.add(:base, "falla") }))
    expect(merge.save).to be(false)
    expect(Person.exists?(secondary.id)).to be(true)
    expect(secondary.reload.producer).to be_present
  end
end
