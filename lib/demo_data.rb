# Fictitious data to show the system (bin/rails demo:seed). Never real
# producers: the client's Excel holds real names, RTN and phones.
class DemoData
  ZONES = [ "Buenas Noches", "Mata de Plátano", "Las Labranzas", "Pueblo Nuevo", "El Chilito" ].freeze
  FIRST_NAMES = %w[Ana Carlos Rosa Luis Marta José Elena Mario Julia Pedro Sofía Tomás Lucía Andrés Carmen].freeze
  LAST_NAMES = [ "Demo Uno", "Demo Dos", "Demo Tres", "Demo Cuatro", "Demo Cinco" ].freeze
  # Farm workers (collaborators), apart from the producers.
  # Fictitious points around Morocelí (El Paraíso), for the maps.
  AREA = { latitude: 14.0..14.25, longitude: -87.0..-86.7 }.freeze
  WORKERS = [ %w[Ramón Demo\ Seis], %w[Teresa Demo\ Siete], %w[Hugo Demo\ Ocho], %w[Irma Demo\ Nueve], %w[Félix Demo\ Diez] ].freeze
  # Carreros: [first names, last names, commission percent, can price].
  HAULERS = [ [ "Rubén", "Demo Once", 10, 50 ], [ "Gloria", "Demo Doce", 8, 55 ] ].freeze
  # Comercialización: [name, kind]. Fictitious, like everything here.
  BUYERS = [ [ "Exportadora Demo del Norte", "exporter" ], [ "Beneficio Demo El Paraíso", "processor" ] ].freeze
  # Control financiero: [category, [subcategories]] and some expenses [subcategory, description, payee, amount, days ago].
  CATEGORIES = { "Transporte (demo)" => [ "Combustible", "Fletes" ], "Mantenimiento (demo)" => [ "Vehículos", "Bodega" ],
                 "Servicios (demo)" => [ "Energía", "Teléfono e internet" ] }.freeze
  EXPENSES = [ [ "Combustible", "Diésel del camión", "Gasolinera Demo", 2_400, 6 ], [ "Fletes", "Flete a El Paraíso", "Transporte Demo", 1_800, 4 ],
               [ "Vehículos", "Cambio de aceite", "Taller Demo", 950, 3 ], [ "Energía", "Factura de la luz", "Empresa de energía demo", 1_250, 2 ],
               [ "Bodega", "Sacos nuevos", "Agroservicio Demo", 3_100, 1 ], [ "Combustible", "Gasolina de la moto", "Gasolinera Demo", 600, 0 ] ].freeze

  def initialize(user)
    @user = user
    @random = Random.new(2026)
  end

  def load
    ActiveRecord::Base.transaction do
      @box, @bank = money_accounts
      zones = ZONES.map { |name| Zone.find_or_create_by!(name:) }
      producers = FIRST_NAMES.each_with_index.map { |first, i| producer(first, LAST_NAMES[i % LAST_NAMES.size], zones[i % zones.size], i) }
      @haulers = haulers
      purchases = (0..6).flat_map { |days_ago| day_of_purchases(producers, Time.zone.today - days_ago) }
      pay_haulers
      invoice_older_purchases(purchases)
      coffee_sales
      loans(producers.map(&:person))
      farms
      finance
    end
  end

  private
    def producer(first, last, zone, index)
      person = Person.find_or_create_by!(first_names: first, last_names: last) do |new_person|
        new_person.zone = zone
        # Every fourth one without a point: the maps say how many are missing.
        new_person.assign_attributes(point) unless index % 4 == 3
      end
      Producer.find_or_create_by!(person:) do |producer|
        producer.kind = index % 5 == 0 ? "intermediary" : "producer"
      end
    end

    def haulers
      HAULERS.map do |first_names, last_names, commission_percent, can_price|
        person = Person.find_or_create_by!(first_names:, last_names:)
        Hauler.find_or_create_by!(person:) { |hauler| hauler.assign_attributes(commission_percent:, can_price:) }
      end
    end

    # Half of each carrero's commissions paid, so their pages show both.
    def pay_haulers
      @haulers.each do |hauler|
        amount = (hauler.balance / 2).round(2)
        hauler.payments.create!(amount:, paid_on: Time.zone.today, payment_method: "cash", created_by: @user) if amount.positive?
      end
    end

    def point
      { latitude: @random.rand(AREA[:latitude]).round(6), longitude: @random.rand(AREA[:longitude]).round(6) }
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
          # About one in three hauled by a carrero.
          hauler: (@haulers.sample(random: @random) if @random.rand(3).zero?),
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
      el_roble = Farm.find_or_create_by!(name: "Finca El Roble (demo)") { |farm| farm.assign_attributes(point) }
      la_cumbre = Farm.find_or_create_by!(name: "Finca La Cumbre (demo)") { |farm| farm.assign_attributes(point) }

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

    def money_accounts
      box = MoneyAccount.find_or_create_by!(name: "Caja de la bodega (demo)") do |account|
        account.assign_attributes(kind: "cash", opening_balance: 150_000, opening_on: Time.zone.today - 30, default_for: %w[cash])
      end
      bank = MoneyAccount.find_or_create_by!(name: "Banco Demo") do |account|
        account.assign_attributes(kind: "bank", bank_name: "Banco Demo", account_number: "0000-1234", opening_balance: 400_000,
                                  opening_on: Time.zone.today - 30, default_for: %w[transfer check])
      end
      [ box, bank ]
    end

    # The week's expenses with their categories, an investment, this month's
    # budget, an owner's contribution and cash taken to the bank. The demo's
    # payments go to the account of their method.
    def finance
      subcategories = CATEGORIES.flat_map do |name, children|
        parent = FinanceCategory.find_or_create_by!(name:, kind: "expense", parent: nil)
        Budget.find_or_create_by!(category: parent, month: Time.zone.today.beginning_of_month) { |budget| budget.amount = 5_000 }
        children.map { |child| FinanceCategory.find_or_create_by!(name: child, kind: "expense", parent:) }
      end.index_by(&:name)
      EXPENSES.each do |category, description, payee, amount, days_ago|
        Expense.create!(kind: "expense", category: subcategories.fetch(category), description:, payee:, amount:, created_by: @user,
                        spent_on: Time.zone.today - days_ago, payment_method: "cash", money_account: @box)
      end
      equipment = FinanceCategory.find_or_create_by!(name: "Equipo (demo)", kind: "investment", parent: nil)
      Expense.create!(kind: "investment", category: equipment, description: "Báscula de plataforma", payee: "Básculas Demo", amount: 28_000,
                      spent_on: Time.zone.today - 5, payment_method: "transfer", money_account: @bank, created_by: @user)
      OtherIncome.create!(money_account: @bank, concept: "Aporte del dueño", amount: 50_000, received_on: Time.zone.today - 7,
                          payment_method: "transfer", created_by: @user)
      AccountTransfer.create!(from_account: @box, to_account: @bank, amount: 20_000, transferred_on: Time.zone.today - 1, created_by: @user)
      [ InvoicePayment, HaulerPayment, LoanPayment, SalePayment ].each do |model|
        model.where(money_account_id: nil, payment_method: "cash").update_all(money_account_id: @box.id)
        model.where(money_account_id: nil, payment_method: %w[transfer check]).update_all(money_account_id: @bank.id)
      end
      Loan.where(money_account_id: nil).where("cash_amount > 0").update_all(money_account_id: @box.id)
      PayrollPayment.where(money_account_id: nil).update_all(money_account_id: @box.id)
      PayrollExpense.where(money_account_id: nil).update_all(money_account_id: @box.id)
    end

    # Trucks of the week's wet parchment: one sold and collected, one sold
    # in part, one weighed at the buyer's and waiting for its sale, and one
    # still on its way.
    def coffee_sales
      buyers = BUYERS.map { |name, kind| Buyer.find_or_create_by!(name:) { |buyer| buyer.kind = kind } }
      [ [ 5, 900, 6, 0, :paid ], [ 3, 800, 5, 1, :partial ], [ 2, 700, 5, -1.5, nil ], [ 0, 600, 4, nil, nil ] ].each_with_index do |(days_ago, gross, sacks, loss, sale), i|
        buyer = buyers[i % buyers.size]
        departed_at = moment_of(Time.zone.today - days_ago)
        shipment = Shipment.create!(buyer:, created_by: @user, departed_at:, coffee_state: "wet_parchment", remission_number: (330 + i).to_s,
                                    carrier_name: "Transporte Demo", origin_gross_weight: gross, origin_sacks: sacks,
                                    origin_humidity_percent: 51, origin_damage_percent: 0)
        next if loss.nil?

        shipment.update!(received_on: departed_at.to_date, weight_note_number: "NP-DEMO-#{i + 1}", destination_gross_weight: gross - (gross * loss.abs / 100),
                         destination_sacks: sacks, destination_humidity_percent: 51, destination_damage_percent: [ loss, 0 ].max)
        next unless sale

        result = SaleIssuer.new(buyer:, user: @user, shipment_ids: [ shipment.id ], payment_status: sale.to_s, payment_method: "transfer",
                                paid_on: departed_at.to_date, amount: (1_000 if sale == :partial),
                                sale: { sold_on: departed_at.to_date, price_unit: "quintal", unit_price: 6_000, buyer_document_number: "Comprobante demo #{i + 1}" }).call
        raise ActiveRecord::RecordInvalid, result.sale unless result.success?
      end
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
