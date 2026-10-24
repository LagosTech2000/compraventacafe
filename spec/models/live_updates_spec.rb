require "rails_helper"

# Which pages each model refreshes when it changes (LiveUpdates).
RSpec.describe LiveUpdates do
  before { allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_later_to) }

  def streams_refreshed
    streams = []
    allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_later_to) { |stream| streams << stream }
    yield
    streams.uniq
  end

  it "refreshes Compra de café after a purchase, an invoice, a payment to it or a producer changes" do
    # A purchase changes the coffee in stock too (Comercialización).
    expect(streams_refreshed { create(:purchase) }).to contain_exactly(:trading, :sales)
    invoice = create(:invoice)
    expect(streams_refreshed { invoice.update!(payment_status: "partial") }).to eq([ :trading ])
    payment = -> { InvoicePayment.create!(invoice:, amount: 1, paid_on: invoice.issued_on, payment_method: "cash", created_by: create(:user)) }
    expect(streams_refreshed(&payment)).to eq([ :trading ])
    expect(streams_refreshed { create(:producer) }).to eq([ :trading ])
  end

  it "refreshes Comercialización after a shipment, a sale or its payment changes" do
    expect(streams_refreshed { create(:shipment) }).to include(:sales)
    sale = create(:sale)
    expect(streams_refreshed { create(:sale_payment, sale:, amount: 1) }).to include(:sales)
  end

  it "refreshes Préstamos after a loan, and both modules after a payment (it may be paid with coffee)" do
    expect(streams_refreshed { create(:loan) }).to eq([ :loans ])
    loan = create(:loan)
    expect(streams_refreshed { create(:loan_payment, loan:) }).to contain_exactly(:loans, :trading)
  end

  it "does not refresh when the change rolls back" do
    streams = streams_refreshed do
      ActiveRecord::Base.transaction(requires_new: true) do
        create(:loan)
        raise ActiveRecord::Rollback
      end
    end
    expect(streams).to be_empty
  end

  it "only takes the streams pages subscribe to" do
    expect { Class.new(ApplicationRecord) { include LiveUpdates; live_updates :farms } }.to raise_error(ArgumentError, /farms/)
  end
end
