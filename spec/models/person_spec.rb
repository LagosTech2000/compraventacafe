require "rails_helper"

RSpec.describe Person do
  it "requires first and last names" do
    person = Person.new
    expect(person).not_to be_valid
    expect(person.errors.attribute_names).to include(:first_names, :last_names)
  end

  it "does not validate dni or rtn (open point)" do
    create(:person, dni: "0704200000968", rtn: "x")
    expect(build(:person, dni: "0704200000968", rtn: "x")).to be_valid
    expect(build(:person, dni: nil, rtn: nil)).to be_valid
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

  describe "#assign_roles" do
    it "adds and removes roles" do
      person = create(:person, :client).reload
      person.assign_roles(client: "0", collaborator: "1")
      person.save!
      person.reload
      expect(person).not_to be_client
      expect(person).to be_collaborator
    end
  end

  describe ".search" do
    it "matches names, dni and rtn, case-insensitively" do
      ana = create(:person, first_names: "Ana", dni: "0801", rtn: "0801X")
      create(:person, first_names: "Luis")
      expect(Person.search("ana")).to eq([ ana ])
      expect(Person.search("0801X")).to eq([ ana ])
    end

    it "treats wildcards literally" do
      create(:person, first_names: "Ana")
      expect(Person.search("%")).to be_empty
    end
  end
end
