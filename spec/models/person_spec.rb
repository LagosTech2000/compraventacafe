require "rails_helper"

RSpec.describe Person do
  it "requires first and last names" do
    person = Person.new
    expect(person).not_to be_valid
    expect(person.errors.attribute_names).to include(:first_names, :last_names)
  end

  describe "dni and rtn" do
    it "are optional" do
      expect(build(:person, dni: nil, rtn: nil)).to be_valid
      expect(build(:person, dni: "  ", rtn: "")).to be_valid
    end

    it "accept 13 and 14 digits" do
      expect(build(:person, dni: "0704200000968", rtn: "07042000009681")).to be_valid
    end

    it "store digits only when typed with dashes or spaces" do
      person = create(:person, dni: "0704-2000-00968", rtn: "0704 2000 009681")
      expect(person.dni).to eq("0704200000968")
      expect(person.rtn).to eq("07042000009681")
    end

    it "reject the wrong length or non-digits, in Spanish" do
      person = build(:person, dni: "07042000", rtn: "0704200000968A")
      expect(person).not_to be_valid
      expect(person.errors[:dni]).to eq([ "debe tener 13 dígitos numéricos, sin letras" ])
      expect(person.errors[:rtn]).to eq([ "debe tener 14 dígitos numéricos, sin letras" ])
    end

    it "are unique per person" do
      create(:person, dni: "0704200000968", rtn: "07042000009681")
      duplicate = build(:person, dni: "0704-2000-00968", rtn: "07042000009681")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:dni]).to include("ya está en uso")
      expect(duplicate.errors[:rtn]).to include("ya está en uso")
    end

    it "are unique in the database too" do
      create(:person, dni: "0704200000968")
      expect { build(:person, dni: "0704200000968").save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "let many people leave them blank" do
      create(:person, dni: nil, rtn: nil)
      expect { create(:person, dni: nil, rtn: nil) }.not_to raise_error
    end
  end

  it "strips blanks and lowercases the email" do
    person = create(:person, first_names: "  Ana ", dni: "  ", email: " Ana@Correo.HN ")
    expect(person.first_names).to eq("Ana")
    expect(person.dni).to be_nil
    expect(person.email).to eq("ana@correo.hn")
  end

  it "can be client and collaborator at the same time" do
    person = create(:person, :client, :collaborator).reload
    expect(person).to be_client
    expect(person).to be_collaborator
  end

  it "allows only one role row of each kind per person" do
    person = create(:person, :client)
    expect { Client.create!(person: person) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "roles from the form" do
    it "adds and removes roles" do
      person = create(:person, :client).reload
      person.assign_attributes(client_role: "0", collaborator_role: "1", producer_role: "0")
      person.save!
      person.reload
      expect(person).not_to be_client
      expect(person).to be_collaborator
    end

    it "requires at least one role when the form sends them, not in code" do
      person = create(:person, :client).reload
      person.assign_attributes(client_role: "0", collaborator_role: "0", producer_role: "0")
      expect(person).not_to be_valid
      expect(person.errors[:base]).to eq([ "Marca al menos un rol: cliente, colaborador o productor." ])
      expect(person.reload).to be_client

      expect(build(:person)).to be_valid
    end

    it "adds a producer of the kind picked, and removes one without purchases" do
      person = Person.create!(first_names: "Ana", last_names: "Zelaya", producer_role: "1", producer_kind: "intermediary")
      expect(person.reload.producer).to have_attributes(kind: "intermediary")

      person.update!(client_role: "1", producer_role: "0")
      expect(person.reload).to have_attributes(client?: true, producer?: false)
    end

    it "keeps the producer role of a producer with purchases" do
      producer = create(:purchase).producer
      person = producer.person.reload
      person.assign_attributes(client_role: "1", producer_role: "0")
      expect(person).not_to be_valid
      expect(person.errors[:base]).to eq([ "No se puede quitar el rol de productor: ya tiene compras, facturas o fincas." ])
      expect(producer.reload).to be_persisted
    end
  end

  it "has an optional zone, which is its producer's" do
    zone = create(:zone)
    person = create(:person, zone:)
    producer = create(:producer, person:)
    expect([ producer.zone, producer.zone_id ]).to eq([ zone, zone.id ])
    expect(build(:person, zone: nil)).to be_valid
  end

  describe ".search" do
    it "matches names, dni and rtn, case-insensitively" do
      ana = create(:person, first_names: "Ana", dni: "0801199912345", rtn: "08011999123456")
      create(:person, first_names: "Luis", dni: "0501198800001")
      expect(Person.search("ana")).to eq([ ana ])
      expect(Person.search("0801199912345")).to eq([ ana ])
      expect(Person.search("08011999123456")).to eq([ ana ])
    end

    it "treats wildcards literally" do
      create(:person, first_names: "Ana")
      expect(Person.search("%")).to be_empty
    end
  end
end
