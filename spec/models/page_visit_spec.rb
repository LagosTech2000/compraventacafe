require "rails_helper"

RSpec.describe PageVisit do
  let(:user) { create(:user) }
  let(:session) { user.sessions.create! }

  it "keeps only the latest KEEP pages of each user" do
    stub_const("PageVisit::KEEP", 3)
    other = create(:user)
    PageVisit.record!(user: other, path: "/other", title: nil, at: 1.day.ago)
    5.times { |i| PageVisit.record!(user:, path: "/page/#{i}", title: nil, at: (5 - i).minutes.ago) }

    expect(user.page_visits.latest.map(&:path)).to eq(%w[/page/4 /page/3 /page/2])
    expect(other.page_visits.count).to eq(1)
  end

  it "is noted with each page a session opens, with its title" do
    session.visited!(path: "/trading/purchases?page=2", title: "  Compras  ")
    expect(user.page_visits.sole).to have_attributes(path: "/trading/purchases?page=2", title: "Compras")
    expect(session.reload).to have_attributes(last_path: "/trading/purchases?page=2", last_page_title: "Compras")
  end

  it "never keeps a path that a browser would open as another site" do
    [ "//evil.example", "/\\evil.example", "https://evil.example", "javascript:alert(1)" ].each do |path|
      session.visited!(path:, title: "Trampa")
    end

    expect(user.page_visits).to be_empty
    expect(session.reload.last_path).to be_nil
  end

  it "goes with its user" do
    PageVisit.record!(user:, path: "/", title: nil)
    expect { user.destroy! }.to change(PageVisit, :count).by(-1)
  end
end
