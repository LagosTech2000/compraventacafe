# Fictitious data to show the system (bin/rails demo:seed). Never real
# producers: the client's Excel holds real names, RTN and phones.
class DemoData
  ZONES = [ "Buenas Noches", "Mata de Plátano", "Las Labranzas", "Pueblo Nuevo", "El Chilito" ].freeze
  FIRST_NAMES = %w[Ana Carlos Rosa Luis Marta José Elena Mario Julia Pedro Sofía Tomás Lucía Andrés Carmen].freeze
  LAST_NAMES = [ "Demo Uno", "Demo Dos", "Demo Tres", "Demo Cuatro", "Demo Cinco" ].freeze

  def initialize(user)
    @user = user
    @random = Random.new(2026)
  end

  def load
    ActiveRecord::Base.transaction do
      zones = ZONES.map { |name| Zone.find_or_create_by!(name:) }
      producers = FIRST_NAMES.each_with_index.map { |first, i| producer(first, LAST_NAMES[i % LAST_NAMES.size], zones[i % zones.size], i) }
      purchases = (0..6).flat_map { |days_ago| day_of_purchases(producers, Time.zone.today - days_ago) }
      invoice_older_purchases(purchases)
      loans(producers.map(&:person))
    end
  end

  private
    def producer(first, last, zone, index)
      person = Person.find_or_create_by!(first_names: first, last_names: last)
      Producer.find_or_create_by!(person:) do |producer|
        producer.zone = zone
        producer.kind = index % 5 == 0 ? "intermediary" : "producer"
      end
    end

    def day_of_purchases(producers, date)
      producers.sample(8, random: @random).map do |producer|
        Purchase.create!(
          producer:, zone: producer.zone, purchased_on: date, created_by: @user,
          coffee_state: "wet_parchment", humidity_percent: 51,
          gross_weight: @random.rand(40..330), price_per_pound: [ 55, 56, 57, 58 ].sample(random: @random)
        )
      end
    end

    # One loan in each state, so the loans module and the payer score have
    # something to show: paid on time, paid late, overdue and current.
    def loans(people)
      today = Time.zone.today
      [
        { days_ago: 90, term: 60, principal: 5_000, paid_after: 50 },
        { days_ago: 80, term: 30, principal: 3_000, paid_after: 45 },
        { days_ago: 70, term: 40, principal: 8_000, partial_after: 20 },
        { days_ago: 15, term: 60, principal: 12_000, partial_after: 10 }
      ].each_with_index do |plan, index|
        loan = Loan.create!(person: people[index], created_by: @user, principal: plan[:principal], monthly_interest_rate: 3,
                            disbursed_on: today - plan[:days_ago], due_on: today - plan[:days_ago] + plan[:term])
        if plan[:paid_after]
          paid_on = loan.disbursed_on + plan[:paid_after]
          pay(loan, paid_on, loan.balance(as_of: paid_on).total_owed)
        else
          pay(loan, loan.disbursed_on + plan[:partial_after], plan[:principal] / 4)
        end
      end
    end

    def pay(loan, paid_on, amount)
      loan.payments.create!(paid_on:, amount:, payment_method: "cash", created_by: @user)
    end

    # Leaves today's purchases uninvoiced; older ones get invoices, some paid.
    def invoice_older_purchases(purchases)
      purchases.reject { |p| p.purchased_on == Time.zone.today }.group_by(&:producer).each_with_index do |(producer, list), i|
        paid = i.even?
        InvoiceIssuer.new(producer:, user: @user, purchase_ids: list.map(&:id),
                          payment_status: paid ? "paid" : "pending", payment_method: ("cash" if paid)).call
      end
    end
end
