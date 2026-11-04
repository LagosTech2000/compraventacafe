require "rails_helper"

# Improvements to the loans module (Fernando, 2026-11-03): what a producer
# owes stands out while buying and invoicing, the loans due soon show on the
# Inicio, and a coffee payment's receipt says what coffee was delivered.
RSpec.describe "Loans collection improvements" do
  let(:admin) { create(:user, :admin) }
  let(:today) { Time.zone.today }
  let(:producer) { create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya")) }

  def page = Nokogiri::HTML(response.body)
  def dom_id(...) = ActionView::RecordIdentifier.dom_id(...)

  before { sign_in admin }

  describe "what the producer owes, while buying" do
    it "stands out on the producer's card in Nueva compra" do
      create(:loan, person: producer.person, due_on: today + 20)

      get trading_producer_card_path(producer)
      expect(page.at_css("[data-producer-owes]").text).to include("Debe 1 préstamo", l_date(today + 20), "abonar con este café")
    end

    it "says it when the purchase is saved, and the purchase offers paying with its coffee" do
      create(:loan, person: producer.person, cash_amount: 1_000, monthly_interest_rate: 0)

      post trading_purchases_path, params: {
        purchase: { producer_id: producer.id, purchased_at: Time.zone.now, coffee_state: "wet_parchment",
                    gross_weight: "146", humidity_percent: "51", damage_percent: "0", price_per_pound: "58" }
      }
      expect(flash[:notice]).to include("Debe L 1,000.00 en préstamos", "Abonar con esta compra")

      get trading_purchase_path(Purchase.last)
      expect(page.at_css("[data-coffee-can-pay]")).to be_present
    end

    it "says nothing about loans to whoever cannot pay them" do
      clerk = create(:user)
      clerk.permissions.create!(module_key: "trading", can_read: true, can_create: true)
      sign_in clerk
      create(:loan, person: producer.person)

      post trading_purchases_path, params: {
        purchase: { producer_id: producer.id, purchased_at: Time.zone.now, coffee_state: "wet_parchment",
                    gross_weight: "146", humidity_percent: "51", damage_percent: "0", price_per_pound: "58" }
      }
      expect(flash[:notice]).not_to include("préstamos")
    end

    it "offers paying with each purchase while invoicing" do
      create(:loan, person: producer.person)
      purchase = create(:purchase, producer:)

      get new_trading_invoice_path(producer_id: producer.id)
      expect(response.body).to include("También puedes tocar «Abonar con esta compra»")
      expect(page.at_css("a[href='#{new_trading_purchase_loan_settlement_path(purchase)}']")).to be_present
    end
  end

  describe "loans due soon" do
    it "counts them on the Inicio and lists them in Tareas pendientes, not the late or later ones" do
      soon = create(:loan, person: producer.person, due_on: today + 3)
      create(:loan, due_on: today + 8)
      create(:loan, due_on: today - 1)

      get root_path
      expect(response.body).to include("1 préstamo vence en los próximos 7 días")

      get pending_work_path
      section = page.at_css("#pending-due_soon_loans")
      expect(section.css("li").size).to eq(1)
      expect(section.at_css("##{dom_id(soon, :pending_soon)}").text).to include("Ana Zelaya", "en 3 días")
    end
  end

  describe "the receipt of a coffee payment" do
    it "says the coffee delivered, its price and what went to the loan" do
      loan = create(:loan, person: producer.person)
      purchase = create(:purchase, producer:)
      payment = create(:loan_payment, loan:, purchase:, payment_method: "coffee", amount: 2_000)

      get loans_loan_payment_path(loan, payment)
      delivery = page.css("[data-coffee-delivery]")
      expect(delivery.size).to eq(2) # original and copy
      expect(delivery.first.text).to include("compra #{purchase.id}", "Pergamino húmedo", "71.05 lb", "0.57", "L 58.00", "L 4,120.90", "L 2,000.00")
    end

    it "is not on a cash payment's receipt" do
      loan = create(:loan)
      payment = create(:loan_payment, loan:)

      get loans_loan_payment_path(loan, payment)
      expect(page.css("[data-coffee-delivery]")).to be_empty
    end
  end

  def l_date(date) = I18n.l(date)
end
