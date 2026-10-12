# Fictitious data to show the system (bin/rails demo:seed). Never real
# producers: the client's Excel holds real names, RTN and phones.
class DemoData
  ZONES = [ "Buenas Noches", "Mata de Plátano", "Las Labranzas", "Pueblo Nuevo", "El Chilito" ].freeze
  FIRST_NAMES = %w[Ana Carlos Rosa Luis Marta José Elena Mario Julia Pedro Sofía Tomás Lucía Andrés Carmen].freeze
  LAST_NAMES = [ "Demo Uno", "Demo Dos", "Demo Tres", "Demo Cuatro", "Demo Cinco" ].freeze
  # Farm workers (collaborators), apart from the producers.
  WORKERS = [ %w[Ramón Demo\ Seis], %w[Teresa Demo\ Siete], %w[Hugo Demo\ Ocho], %w[Irma Demo\ Nueve], %w[Félix Demo\ Diez] ].freeze

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
      farms
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

    # A working hour of that day, never later than now.
    def moment_of(date)
      [ date.in_time_zone.change(hour: @random.rand(7..16), min: @random.rand(60)), Time.current ].min
    end

    def day_of_purchases(producers, date)
      producers.sample(8, random: @random).map do |producer|
        coffee_state = %w[wet_parchment wet_parchment wet_parchment dry_parchment cherry].sample(random: @random)
        inputs = PurchaseDefaults.inputs_for(coffee_state)
        inputs[:damage_percent] = [ 0, 2, 2.2, 2.5 ].sample(random: @random) if inputs.key?(:damage_percent)
        Purchase.create!(
          producer:, zone: producer.zone, purchased_at: moment_of(date), created_by: @user, coffee_state:, **inputs,
          gross_weight: @random.rand(40..330), price_per_pound: [ 55, 56, 57, 58 ].sample(random: @random)
        )
      end
    end

    # One loan in each state, so the loans module and the payer score have
    # something to show: paid on time, paid late, overdue and current.
    def loans(people)
      supplies = demo_supplies
      today = Time.zone.today
      [
        { days_ago: 90, term: 60, cash: 5_000, paid_after: 50 },
        { days_ago: 80, term: 30, cash: 3_000, paid_after: 45 },
        { days_ago: 70, term: 40, cash: 3_000, supplies: { "Abono 18-46-0" => 4 }, partial_after: 20 },
        { days_ago: 15, term: 60, cash: 0, supplies: { "Urea 46 %" => 6, "Fungicida cúprico" => 2 }, partial_after: 10 }
      ].each_with_index do |plan, index|
        items = plan.fetch(:supplies, {}).map do |name, quantity|
          { supply: supplies.fetch(name), quantity:, unit_price: supplies.fetch(name).default_price }
        end
        loan = Loan.create!(person: people[index], created_by: @user, cash_amount: plan[:cash], monthly_interest_rate: 3,
                            supply_items_attributes: items,
                            disbursed_on: today - plan[:days_ago], due_on: today - plan[:days_ago] + plan[:term])
        if plan[:paid_after]
          paid_on = loan.disbursed_on + plan[:paid_after]
          pay(loan, paid_on, loan.balance(as_of: paid_on).total_owed)
        else
          pay(loan, loan.disbursed_on + plan[:partial_after], (loan.principal / 4).round(2))
        end
      end
    end

    # Fictitious catalog of supplies lent in kind.
    def demo_supplies
      {
        "Abono 18-46-0" => [ "saco", 1_250 ], "Urea 46 %" => [ "saco", 1_100 ], "Fungicida cúprico" => [ "litro", 380 ]
      }.to_h do |name, (unit, price)|
        [ name, Supply.find_or_create_by!(name:) { |supply| supply.assign_attributes(unit:, default_price: price) } ]
      end
    end

    # Two farms with a payroll of each kind: attendance and cans recorded up
    # to today, the oldest periods paid (one with a loan deduction) and the
    # last one that ended left to pay, plus some expenses.
    def farms
      today = Time.zone.today
      start = today.beginning_of_week - 14
      people = WORKERS.map do |first_names, last_names|
        Person.find_or_create_by!(first_names:, last_names:).tap { |person| person.collaborator || person.create_collaborator! }
      end
      el_roble = Farm.find_or_create_by!(name: "Finca El Roble (demo)")
      la_cumbre = Farm.find_or_create_by!(name: "Finca La Cumbre (demo)")

      daily = Payroll.create!(farm: el_roble, name: "Limpia de lotes", kind: "daily", pay_frequency: "weekly", starts_on: start, created_by: @user)
      worker = daily.roles.create!(name: "Jornalero", daily_wage: 300)
      foreman = daily.roles.create!(name: "Caporal", daily_wage: 450)
      daily_members = people.each_with_index.map do |person, index|
        daily.members.create!(person:, role: index.zero? ? foreman : worker, daily_wage_override: (350 if index == 1))
      end
      (start..today).reject(&:sunday?).each do |date|
        daily_members.each do |member|
          next if @random.rand < 0.1

          PayrollAttendance.create!(member:, worked_on: date, day_fraction: @random.rand < 0.15 ? 0.5 : 1)
        end
      end
      loan = Loan.create!(person: people.first, created_by: @user, cash_amount: 2_000, monthly_interest_rate: 2,
                          disbursed_on: start - 30, due_on: today + 60)
      first_period = daily.periods.first
      PayrollPaymentIssuer.new(payroll: daily, period: first_period, user: @user, paid_on: first_period.ends_on,
                               loan_amounts: { loan.id => 500 }, with_loans: true).save

      harvest = Payroll.create!(farm: la_cumbre, name: "Corte 2026", kind: "harvest", pay_frequency: "biweekly",
                                starts_on: today - 10, can_price: 28, created_by: @user)
      harvest_foreman = harvest.members.create!(person: people.second, role: harvest.roles.create!(name: "Caporal", daily_wage: 400))
      harvest_members = people.last(3).map { |person| harvest.members.create!(person:) }
      ((today - 10)..today).reject(&:sunday?).each do |date|
        harvest_members.each { |member| HarvestEntry.create!(member:, worked_on: date, cans: @random.rand(6..18)) }
        PayrollAttendance.create!(member: harvest_foreman, worked_on: date, day_fraction: 1)
      end

      by_task = Payroll.create!(farm: la_cumbre, name: "Obras de mantenimiento", kind: "task", pay_frequency: "monthly",
                                starts_on: today.beginning_of_month, created_by: @user)
      task_members = people.first(3).map { |person| by_task.members.create!(person:) }
      by_task.tasks.create!(name: "Chapia del lote 2", amount: 1_500, member_ids: task_members.map(&:id), completed_on: today)
      by_task.tasks.create!(name: "Reparar cerco", amount: 800, member_ids: task_members.first(2).map(&:id))

      transport = ExpenseCategory.find_or_create_by!(name: "Transporte")
      tools = ExpenseCategory.find_or_create_by!(name: "Herramientas")
      daily.expenses.create!(category: transport, spent_on: start + 1, description: "Pick-up para el personal", amount: 600, created_by: @user)
      daily.expenses.create!(category: tools, spent_on: start + 2, description: "Limas y machetes", amount: 1_150, created_by: @user)
      harvest.expenses.create!(category: transport, spent_on: today - 3, description: "Flete del café cortado", amount: 900, created_by: @user)
    end

    def pay(loan, paid_on, amount)
      loan.payments.create!(paid_on:, amount:, payment_method: "cash", created_by: @user)
    end

    # Leaves today's purchases uninvoiced; older ones get invoices: some
    # paid, some paid in part (half, in cash) and some pending.
    def invoice_older_purchases(purchases)
      purchases.reject { |p| p.purchased_at.to_date == Time.zone.today }.group_by(&:producer).each_with_index do |(producer, list), i|
        status = %w[paid partial pending][i % 3]
        amount = (list.sum(&:amount_to_pay) / 2).round(2) if status == "partial"
        InvoiceIssuer.new(producer:, user: @user, purchase_ids: list.map(&:id), payment_status: status,
                          payment_method: ("cash" unless status == "pending"), amount:).call
      end
    end
end
