require "rails_helper"

# Profile photos of people and users (Fernando, 2026-10-13): stored in the
# database (ProfilePhoto), only real images, served to signed-in users.
RSpec.describe "Profile photos" do
  let(:admin) { create(:user, :admin) }

  def page = Nokogiri::HTML(response.body)

  it "takes a producer's photo from its form, shows it on its page and audits it" do
    producer = create(:producer)
    sign_in admin

    patch trading_producer_path(producer), params: { producer: { person_attributes: { id: producer.person.id, photo_upload: uploaded_picture } } }
    photo = producer.person.reload.photo
    expect(photo).to have_attributes(content_type: "image/png", byte_size: File.size(png_picture(40, 40)))
    expect(AuditEvent.where(auditable: photo, action: "create")).to exist
    expect(AuditEvent.find_by(auditable: photo).changeset).not_to have_key("data") # never the bytes

    get trading_producer_path(producer)
    src = page.at_css("main h1").ancestors("div")[1].at_css("img")["src"]
    expect(src).to eq(profile_photo_path(photo, v: photo.version))

    get src
    expect(response.media_type).to eq("image/png")
    expect(response.body.b).to eq(photo.data)
  end

  it "takes and removes a person's photo from Administración → Personas" do
    person = create(:person)
    sign_in admin

    patch administration_person_path(person), params: { person: { photo_upload: uploaded_picture, client_role: "1" } }
    expect(person.reload.photo).to be_present

    get edit_administration_person_path(person)
    expect(page.at_css("input[type=checkbox][name='person[remove_photo]']")).to be_present

    patch administration_person_path(person), params: { person: { remove_photo: "1", client_role: "1" } }
    expect(person.reload.photo).to be_nil
    expect(ProfilePhoto.count).to eq(0)
  end

  it "refuses what is not an image or is too big, in Spanish, and keeps the old photo" do
    person = create(:person)
    person.update!(photo_upload: uploaded_picture)
    sign_in admin

    patch administration_person_path(person), params: { person: { photo_upload: fixture_file_upload("logo.svg", "image/png"), client_role: "1" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Foto de perfil debe ser una imagen JPG, PNG o WebP")

    patch administration_person_path(person), params: { person: { photo_upload: uploaded_picture(800, 800, noise: true), client_role: "1" } }
    expect(response.body).to include("Foto de perfil pesa más de 1 MB")
    expect(person.reload.photo.byte_size).to eq(File.size(png_picture(40, 40)))
  end

  it "is seen only with a session" do
    person = create(:person)
    person.update!(photo_upload: uploaded_picture)

    get profile_photo_path(person.photo)
    expect(response).to redirect_to(new_session_path)
  end

  it "never loads the bytes to show a photo in a list" do
    person = create(:person)
    person.update!(photo_upload: uploaded_picture)

    info = Person.includes(:photo_info).find(person.id).photo_info
    expect(info.attributes).not_to have_key("data")
    expect(info.version).to eq(person.photo.version)
  end
end
