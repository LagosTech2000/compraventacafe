require "rails_helper"

# «Ver productor» in the invoice's payments: the producer's page (phone,
# DNI, address…) opens on top, to call them while paying.
RSpec.describe "Invoice producer link" do
  def producer_link
    Nokogiri::HTML(response.body).at_css("[data-invoice-producer]")
  end

  it "opens the producer's page in the modal, over the invoice opened in one too" do
    invoice = create(:invoice)
    sign_in create(:user, :admin)

    get trading_invoice_path(invoice)
    expect(producer_link["href"]).to eq(trading_producer_path(invoice.producer))
    expect(producer_link["data-turbo-frame"]).to eq("modal")
    expect(producer_link.text).to include("Ver productor")

    get trading_invoice_path(invoice), headers: { "Turbo-Frame" => "modal" }
    expect(producer_link["data-turbo-frame"]).to eq("modal_2")

    get trading_producer_path(invoice.producer), headers: { "Turbo-Frame" => "modal_2" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(invoice.producer.person.full_name)
  end
end
