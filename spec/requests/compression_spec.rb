require "rails_helper"

# Pages go compressed to browsers that ask for it (Rack::Deflater).
RSpec.describe "Compression" do
  let(:admin) { create(:user, :admin) }

  it "compresses pages, but not the logo" do
    sign_in admin

    get trading_purchases_path, headers: { "Accept-Encoding" => "gzip" }
    expect(response.headers["content-encoding"]).to eq("gzip")
    expect(Zlib.gunzip(response.body)).to include("Compras")

    SiteSetting.instance.update!(logo: fixture_file_upload("logo.png", "image/png"))
    get site_logo_path, headers: { "Accept-Encoding" => "gzip" }
    expect(response.headers["content-encoding"]).to be_nil
  end
end
