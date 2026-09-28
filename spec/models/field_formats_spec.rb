require "rails_helper"

RSpec.describe "Field format convention" do
  def person(**attributes)
    build(:person, **attributes).tap(&:valid?)
  end

  describe "names" do
    it "accept letters, accents, spaces, apostrophes, dots and hyphens" do
      expect(person(first_names: "María José", last_names: "O'Neill Núñez-Peña Jr.").errors).to be_empty
    end

    it "reject digits and symbols" do
      expect(person(first_names: "Juan2").errors[:first_names]).to be_present
      expect(person(last_names: "@López").errors[:last_names]).to be_present
    end

    it "squish extra spaces" do
      expect(person(first_names: "  Ana   María ").first_names).to eq("Ana María")
    end
  end

  describe "phone" do
    it "stores 8 digits from common ways of typing it" do
      [ "9999-0000", "9999 0000", "+504 9999-0000", "504 99990000", "99990000" ].each do |typed|
        expect(person(phone: typed)).to have_attributes(phone: "99990000"), typed
      end
    end

    it "rejects other lengths and letters, in Spanish" do
      [ "9999-000", "9999-00000", "9999-OOOO" ].each do |typed|
        expect(person(phone: typed).errors[:phone]).to eq([ "debe tener 8 dígitos (puede empezar con +504)" ]), typed
      end
    end
  end

  describe "email" do
    it "rejects malformed addresses" do
      expect(person(email: "juan@").errors[:email]).to eq([ "no es un correo válido" ])
      expect(person(email: "juan@example.com").errors[:email]).to be_empty
    end

    it "applies to users too" do
      user = build(:user, email_address: "no-es-correo")
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to eq([ "no es un correo válido" ])
    end
  end
end
