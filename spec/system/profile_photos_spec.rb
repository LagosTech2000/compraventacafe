require "rails_helper"

# Profile photos (Fernando, 2026-10-13): the browser shrinks a phone's photo
# before sending it (photo_input_controller.js), so it fits the limit.
RSpec.describe "Profile photos", type: :system do
  it "shrinks a big photo in the browser, previews it and saves it" do
    producer = create(:producer)
    big = png_picture(1500, 1500, noise: true)
    expect(File.size(big)).to be > ProfilePhoto::MAX_SIZE
    sign_in_as(create(:user, :admin))
    visit edit_trading_producer_path(producer)

    attach_file "producer_person_attributes_photo_upload", big
    expect(page).to have_css("img[data-photo-input-target=preview][src^='blob:']")
    expect(page.evaluate_script("document.getElementById('producer_person_attributes_photo_upload').files[0].type")).to eq("image/jpeg")

    within("main form") { find("[type=submit]").click }
    expect(page).to have_text("Productor actualizado")
    photo = producer.person.reload.photo
    expect(photo.content_type).to eq("image/jpeg")
    expect(photo.byte_size).to be <= ProfilePhoto::MAX_SIZE
    expect(page).to have_css("main img[src='#{Rails.application.routes.url_helpers.profile_photo_path(photo, v: photo.version)}']")
  end
end
