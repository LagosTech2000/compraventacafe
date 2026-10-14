require "rails_helper"

# Browsers ask for these on their own (the tab, the iPhone home screen), even
# when the page does not link them: missing, each visit left a 404 in the
# audit log (2026-10-14).
RSpec.describe "Browser icons" do
  {
    "/favicon.ico" => "image/vnd.microsoft.icon",
    "/icon.png" => "image/png",
    "/icon.svg" => "image/svg+xml",
    "/apple-touch-icon.png" => "image/png",
    "/apple-touch-icon-precomposed.png" => "image/png"
  }.each do |path, type|
    it "serves #{path} without auditing an error" do
      sign_in create(:user)
      expect { get path }.not_to change { AuditEvent.where(action: "error").count }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(type)
    end
  end

  # ?v= busts the year-long cache of public/ (production.rb) when they change.
  it "links the icons from the layout" do
    sign_in create(:user)
    get root_path
    head = Nokogiri::HTML(response.body).at_css("head")
    expect(head.css("link[rel=icon]").map { it["href"] }).to contain_exactly("/icon.png?v=2", "/icon.svg?v=2")
    expect(head.at_css("link[rel=apple-touch-icon]")["href"]).to eq("/apple-touch-icon.png?v=2")
  end

  it "does not count icons against the per-IP limit" do
    expect(Rack::Attack::UNCOUNTED_PATHS).to match("/apple-touch-icon-precomposed.png").and match("/favicon.ico")
  end
end
