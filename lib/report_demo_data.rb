# A year of fictitious operation, so the reports have something to show
# (bin/rails demo:reports): every day from September 1, 2025 (season 2025)
# to today, as the business would live it.
#
#   coffee   purchases that follow the harvest (few in the summer, many from
#            November to February), at working hours, invoiced and paid a
#            few days later; some paid with coffee to the producer's loans
#   loans    lent mostly before the harvest (cash, supplies or both), paid
#            with coffee, in cash or from payrolls; some fall overdue
#   sales    trucks of parchment leave for the buyers when there is enough
#            in stock, are weighed there a day or two later, sold on the
#            buyer's weight and collected some days after
#   farms    three farms with year-round maintenance (by day), coffee
#            picking each harvest (by cans, with foremen by day) and works
#            (by task), paid period by period, plus their expenses
#
# Everything goes through the models and services (validations, stored
# calculations, audit), the way the screens do it. Names are made up from
# common first names and surnames; never the client's real producers.
class ReportDemoData
  START = Date.new(2025, 9, 1)
  MARKER_FARM = "Finca Los Pinos (demo)".freeze

  FIRST_NAMES = %w[José María Juan Ana Carlos Rosa Luis Marta Pedro Elena Mario Julia Francisco Carmen Jorge Lucía Miguel
                   Sofía Ramón Teresa Óscar Gloria Héctor Dilcia Wilmer Yolanda Santos Reina Edwin Norma Elvin Iris Melvin
                   Daysi Nelson Sandra Wilfredo Karla Arnold Lesly].freeze
  SURNAMES = %w[Hernández López Martínez García Rodríguez Pérez Sánchez Ramírez Flores Cruz Reyes Mejía Zelaya Castro Ortiz
                Romero Aguilar Paz Rivera Mendoza Fuentes Cárcamo Bonilla Osorto Murillo Pineda Lara Orellana Euceda Chinchilla].freeze
  ZONES = [ "Buenas Noches", "Mata de Plátano", "Las Labranzas", "Pueblo Nuevo", "El Chilito", "San Isidro", "Los Planes", "El Zapote" ].freeze
  # Purchases a working day, by month: the harvest runs from October to
  # March and peaks in December and January.
  PURCHASES_A_DAY = { 9 => 3, 10 => 8, 11 => 17, 12 => 24, 1 => 24, 2 => 18, 3 => 11, 4 => 5, 5 => 3, 6 => 2, 7 => 2, 8 => 2 }.freeze
  # Cans a picker cuts on a good day, by month.
  CANS_A_DAY = { 10 => 7, 11 => 11, 12 => 15, 1 => 14, 2 => 9 }.freeze
  # When producers arrive: mid-morning and mid-afternoon.
  HOURS = { 6 => 1, 7 => 3, 8 => 6, 9 => 8, 10 => 6, 11 => 3, 12 => 2, 13 => 4, 14 => 6, 15 => 5, 16 => 3, 17 => 1 }.freeze
  SUPPLIES = { "Abono 18-46-0" => [ "saco", 1_250 ], "Urea 46 %" => [ "saco", 1_100 ], "Fungicida cúprico" => [ "litro", 380 ],
               "Abono 12-24-12" => [ "saco", 1_180 ], "Herbicida" => [ "galón", 650 ], "Cal agrícola" => [ "saco", 220 ],
               "Insecticida" => [ "litro", 540 ], "Foliar" => [ "litro", 310 ] }.freeze
  EXPENSES = { "Transporte" => [ "Flete del café cortado", "Pick-up para el personal", "Acarreo de insumos" ],
               "Herramientas" => [ "Limas y machetes", "Canastos para el corte", "Tijeras de poda" ],
               "Alimentación" => [ "Almuerzo de los cortadores", "Café y pan para el personal" ],
               "Combustible" => [ "Diésel del tractor", "Gasolina de la motosierra" ],
               "Mantenimiento" => [ "Reparación de la bomba", "Cambio de llantas", "Arreglo del beneficio" ],
               "Fertilizantes" => [ "Abono para el lote 3", "Foliar para el vivero" ] }.freeze

  # Comercialización: fictitious buyers [name, kind].
  BUYERS = [ [ "Exportadora Demo Montecillos", "exporter" ], [ "Exportadora Demo Copán", "exporter" ],
             [ "Beneficio Demo Danlí", "processor" ], [ "Comercial Demo Oriente", "other" ] ].freeze
  # Control financiero: first-level categories and their subcategories, with
  # what a usual expense of each costs.
  BUSINESS_EXPENSES = { "Transporte" => { "Combustible" => 1_500, "Fletes" => 2_500, "Llantas y repuestos" => 3_000 },
                        "Bodega" => { "Sacos" => 2_000, "Mantenimiento" => 1_200 },
                        "Servicios" => { "Energía" => 1_400, "Teléfono e internet" => 900, "Agua" => 300 },
                        "Administración" => { "Papelería" => 400, "Contador" => 3_500 } }.freeze
  INVESTMENTS = [ [ "Vehículos", "Camión usado", 450_000 ], [ "Equipo", "Báscula de plataforma", 28_000 ], [ "Equipo", "Secadora de café", 180_000 ] ].freeze
  # A truck leaves once this many net pounds of a state are in stock.
  TRUCK_POUNDS = 1_500

  ProducerPlan = Struct.new(:producer, :weight, :from, :until, keyword_init: true)

  attr_reader :counts

  def initialize(user, from: START, to: Time.zone.today, seed: 2025)
    @user = user
    @from = from
    @to = to
    @random = Random.new(seed)
    @counts = Hash.new(0)
    @uninvoiced = Hash.new { |hash, producer| hash[producer] = [] }
    @pending = []
    @in_transit = []
    @to_collect = []
  end

  def self.loaded? = Farm.exists?(name: MARKER_FARM)

  def load
    ActiveRecord::Base.transaction { prepare }
    (@from..@to).each_slice(7) do |week|
      ActiveRecord::Base.transaction { week.each { |date| day(date) } }
    end
    ActiveRecord::Base.transaction { budget_and_accounts }
    self
  end

  private
    # --- Who and what ---------------------------------------------------

    def prepare
      @zones = ZONES.map { |name| Zone.find_or_create_by!(name:) }
      @clerks = [ @user ] + [ [ "Cajera de Turno Demo", "demo-caja" ], [ "Encargado de Báscula Demo", "demo-bascula" ] ].map do |name, email|
        User.find_or_create_by!(email_address: "#{email}@example.test") do |user|
          user.assign_attributes(name:, password: SecureRandom.base58(24), active: false)
        end
      end
      @supplies = SUPPLIES.map do |name, (unit, price)|
        Supply.find_or_create_by!(name:) { |supply| supply.assign_attributes(unit:, default_price: price) }
      end
      @categories = EXPENSES.keys.to_h { |name| [ name, ExpenseCategory.find_or_create_by!(name:) ] }
      @producers = producers
      @workers = workers
      @farms = farms
      @accounts = [ [ "Caja (demo)", "cash", %w[cash], 100_000 ], [ "Cuenta principal (demo)", "bank", %w[transfer check], 600_000 ] ].map do |name, kind, methods, opening|
        MoneyAccount.find_or_create_by!(name:) do |account|
          account.assign_attributes(kind:, bank_key: ("atlantida" if kind == "bank"), default_for: methods, opening_balance: opening, opening_on: @from)
        end
      end
      @business_categories = BUSINESS_EXPENSES.to_h do |name, children|
        parent = FinanceCategory.find_or_create_by!(name:, kind: "expense", parent: nil)
        [ parent, children.to_h { |child, cost| [ FinanceCategory.find_or_create_by!(name: child, kind: "expense", parent:), cost ] } ]
      end
      @buyers = BUYERS.map { |name, kind| Buyer.find_or_create_by!(name:) { |buyer| buyer.kind = kind } }
    end

    def person(zone: nil)
      Person.create!(first_names: pick(FIRST_NAMES), last_names: "#{pick(SURNAMES)} #{pick(SURNAMES)}", zone:)
    end

    # 70 producers. A few big ones carry much of the coffee (their weight);
    # some stop selling halfway and some only start this season.
    def producers
      (1..70).map do |rank|
        kind = rank <= 6 ? "intermediary" : (rank % 23).zero? ? "own_farm" : "producer"
        producer = Producer.create!(person: person(zone: pick(@zones)), kind:,
                                    new_farm_name: ("Finca #{pick(%w[El Mirador La Esperanza Santa Rosa El Paraíso Las Brisas])}" if @random.rand < 0.4))
        from = rank > 62 ? Date.new(2026, 9, 1) + @random.rand(30) : @from
        stops = Date.new(2026, 1, 10) + @random.rand(80) if rank.between?(30, 37)
        ProducerPlan.new(producer:, weight: 1.0 / (rank**0.55), from:, until: stops)
      end
    end

    # Farm workers: collaborators, ten of them small producers too.
    def workers
      people = (1..60).map { person }
      people += @producers.last(10).map { |plan| plan.producer.person }
      people.each { |someone| someone.collaborator || someone.create_collaborator! }
      people
    end

    def farms
      [ "Finca El Roble (demo)", "Finca La Cumbre (demo)", MARKER_FARM ].each_with_index.map do |name, index|
        farm = Farm.find_or_create_by!(name:)
        crew = @workers.slice(index * 23, 23)
        { farm:, crew:, payrolls: payrolls_for(farm, crew, index) }
      end
    end

    def payrolls_for(farm, crew, index)
      maintenance = [ [ "Mantenimiento 2025-2026", @from, Date.new(2026, 8, 31) ], [ "Mantenimiento 2026-2027", Date.new(2026, 9, 1), nil ] ]
                    .map { |name, starts_on, ends_on| daily_payroll(farm, name, starts_on, ends_on, crew.first(7)) }
      harvests = [ [ "Corte 2025-2026", Date.new(2025, 10, 6), Date.new(2026, 2, 27), 30 + index ],
                   [ "Corte 2026-2027", Date.new(2026, 10, 1), nil, 32 + index ] ]
                 .map { |name, starts_on, ends_on, price| harvest_payroll(farm, name, starts_on, ends_on, price, crew) }
      works = Payroll.create!(farm:, name: "Obras 2026", kind: "task", pay_frequency: "monthly", starts_on: Date.new(2026, 1, 1),
                              created_by: @user)
      crew.first(9).each { |worker| works.members.create!(person: worker) }
      (maintenance + harvests + [ works ]).select { |payroll| payroll.starts_on <= @to }
    end

    def daily_payroll(farm, name, starts_on, ends_on, people)
      payroll = Payroll.create!(farm:, name:, kind: "daily", pay_frequency: "weekly", starts_on:, ends_on:, created_by: @user)
      roles = { "Jornalero" => 300, "Caporal" => 450, "Motosierrista" => 400 }.to_h { |role, wage| [ role, payroll.roles.create!(name: role, daily_wage: wage) ] }
      people.each_with_index do |someone, index|
        role = index.zero? ? roles["Caporal"] : index == 1 ? roles["Motosierrista"] : roles["Jornalero"]
        payroll.members.create!(person: someone, role:, daily_wage_override: (330 if index == 2))
      end
      payroll
    end

    # Pickers by cans, and two foremen with a daily wage: the crew that does
    # not do maintenance.
    def harvest_payroll(farm, name, starts_on, ends_on, can_price, people)
      payroll = Payroll.create!(farm:, name:, kind: "harvest", pay_frequency: "biweekly", starts_on:, ends_on:, can_price:, created_by: @user)
      foreman = payroll.roles.create!(name: "Caporal", daily_wage: 420)
      pickers = people.drop(7)
      pickers.first(2).each { |someone| payroll.members.create!(person: someone, role: foreman) }
      pickers.drop(2).each { |someone| payroll.members.create!(person: someone) }
      payroll
    end

    # --- One day --------------------------------------------------------

    def day(date)
      lend(date)
      buy(date)
      invoice_and_pay(date)
      ship(date)
      receive_and_sell(date)
      collect_sales(date)
      collect(date)
      spend_business(date)
      work(date)
    end

    # Loans: mostly from March to August, to get to the harvest.
    def lend(date)
      chances = [ 3, 4, 5, 6, 7, 8 ].include?(date.month) ? 0.65 : 0.25
      return unless @random.rand < chances && !date.sunday?

      borrower = @random.rand < 0.7 ? weighted_producer(date)&.producer&.person : pick(@workers)
      return if borrower.nil? || borrower.loans.unpaid.count >= 2

      kind = pick(%w[cash cash supplies mixed])
      items = kind == "cash" ? [] : @supplies.sample(@random.rand(1..3), random: @random).map do |supply|
        { supply:, quantity: @random.rand(2..15), unit_price: supply.default_price }
      end
      cash = kind == "supplies" ? 0 : (@random.rand(2..40) * 500)
      loan = Loan.create!(person: borrower, created_by: pick(@clerks), cash_amount: cash, monthly_interest_rate: pick([ 2, 2.5, 3, 3 ]),
                          supply_items_attributes: items, disbursed_on: date, due_on: date + pick([ 60, 90, 120, 150, 180, 240 ]))
      @bad_payers ||= []
      @bad_payers << loan.id if @random.rand < 0.18
      @counts[:loans] += 1
    end

    def buy(date)
      expected = PURCHASES_A_DAY.fetch(date.month) * (date.sunday? ? 0.25 : 1)
      count = (expected * (0.6 + @random.rand * 0.8)).round
      count.times do
        plan = weighted_producer(date) or next
        purchase = purchase_for(plan.producer, date)
        @counts[:purchases] += 1
        if @random.rand < 0.012
          purchase.update!(voided_at: purchase.purchased_at + 1.hour, voided_by: pick(@clerks))
          next
        end
        pay_loans_with_coffee(purchase, date)
        @uninvoiced[plan.producer] << purchase
      end
    end

    def purchase_for(producer, date)
      state = producer.kind == "intermediary" ? pick(%w[wet_parchment dry_parchment dry_parchment]) : pick(%w[wet_parchment wet_parchment wet_parchment dry_parchment cherry])
      inputs = PurchaseDefaults.inputs_for(state)
      inputs[:humidity_percent] = (inputs[:humidity_percent] + @random.rand(-3.0..3.0)).round(1) if inputs[:humidity_percent]
      inputs[:damage_percent] = pick([ 0, 0, 1.5, 2, 2.2, 2.5 ]) if inputs.key?(:damage_percent)
      inputs[:yield_factor] = (0.17 + @random.rand * 0.03).round(4) if inputs[:yield_factor]
      size = producer.kind == "intermediary" ? @random.rand(300..1_200) : @random.rand(60..520)
      weight = if @random.rand < 0.3
        sacks = [ (size / 150.0).ceil, 1 ].max
        { weight_mode: "weighings", weighings_attributes: Array.new([ sacks, 5 ].min) { { gross_weight: (size / [ sacks, 5 ].min.to_f).round, sacks: [ sacks / 5, 1 ].max } } }
      else
        { weight_mode: "single", gross_weight: size }
      end
      Purchase.create!(producer:, zone: producer.zone, farm: producer.farms.first, purchased_at: moment(date), created_by: pick(@clerks), coffee_state: state,
                       price_per_pound: price(state, date), **inputs, **weight)
    end

    # The market moves along the season; dry parchment pays more, cherry less.
    def price(state, date)
      days = (date - START).to_i
      base = 54 + 4 * Math.sin(days / 365.0 * 2 * Math::PI + 1) + days * 0.006
      base += { "dry_parchment" => 3, "cherry" => -1.5 }.fetch(state, 0)
      ((base + @random.rand(-1.0..1.0)) * 2).round / 2.0
    end

    def moment(date)
      hour = weighted(HOURS)
      [ date.in_time_zone.change(hour:, min: @random.rand(60)), Time.current ].min
    end

    # Now and then a producer who owes pays part with the coffee.
    def pay_loans_with_coffee(purchase, date)
      loans = purchase.producer.person.loans.unpaid.order(:due_on).to_a
      return if loans.empty? || @random.rand > 0.4

      loan = loans.first
      owed = loan.balance(as_of: date).total_owed
      share = (purchase.total * (0.1 + @random.rand * 0.25)).round(2)
      amount = [ share, owed, purchase.available_for_loans ].min
      return unless amount.positive?

      settlement = PurchaseLoanSettlement.new(purchase:, user: pick(@clerks), paid_on: date, amounts: { loan.id => amount })
      @counts[:coffee_payments] += 1 if settlement.save
    end

    # Purchases are invoiced a day or a few later, and invoices are paid
    # soon after (the most recent ones are left pending or uninvoiced).
    def invoice_and_pay(date)
      @uninvoiced.each do |producer, purchases|
        ready = purchases.select { |purchase| (date - purchase.purchased_at.to_date).to_i >= 1 }
        next if ready.empty? || @random.rand > 0.55

        invoice = Invoice.create!(producer:, created_by: pick(@clerks), issued_on: date, payment_status: "pending", purchases: ready)
        @pending << invoice
        purchases.replace(purchases - ready)
        @counts[:invoices] += 1
      end
      @pending.reject! do |invoice|
        waited = (date - invoice.issued_on).to_i
        next false if @random.rand > (waited.zero? ? 0.2 : waited <= 5 ? 0.15 : 0.06)

        method = weighted("cash" => 6, "transfer" => 3, "check" => 1)
        # Some are paid in two parts: half now, the rest another day.
        if invoice.payments.empty? && invoice.balance_due > 1 && @random.rand < 0.25
          invoice.payments.create!(amount: (invoice.balance_due / 2).round(2), paid_on: date, payment_method: method, created_by: invoice.created_by)
          next false
        end
        invoice.mark_paid(method:, on: date)
      end
    end

    # A truck of a parchment state leaves when its stock is enough, now and then.
    def ship(date)
      return if date.sunday?

      stock = CoffeeStock.new(date)
      %w[wet_parchment dry_parchment].each do |state|
        available = stock.row(state).stock
        next if available < TRUCK_POUNDS || @random.rand > 0.45

        net = [ available, TRUCK_POUNDS + @random.rand(0..2_500) ].min
        humidity = PurchaseDefaults::HUMIDITY_PERCENT.fetch(state)
        gross = (net / (1 - humidity / 100.0)).round
        sacks = (gross / PurchaseCalculation::SACK_WEIGHT.to_f).ceil
        shipment = Shipment.create!(buyer: pick(@buyers), created_by: pick(@clerks), departed_at: moment(date), coffee_state: state,
                                    remission_number: (400 + @counts[:shipments]).to_s, carrier_name: pick([ "Transporte Demo", "Camión propio" ]),
                                    origin_gross_weight: gross + sacks, origin_sacks: sacks, origin_humidity_percent: humidity, origin_damage_percent: 0)
        @in_transit << [ shipment, date + @random.rand(0..2) ]
        @counts[:shipments] += 1
      end
    end

    # Weighed at the buyer's (a little less, some with damage) and sold the
    # same day: by the quintal of 100 lb to processors, by the pound to the rest.
    def receive_and_sell(date)
      arrived, @in_transit = @in_transit.partition { |_, on| on <= date }
      arrived.each do |shipment, on|
        loss = @random.rand(0.0..0.025)
        shipment.update!(received_on: on, weight_note_number: "NP-#{shipment.number}", destination_gross_weight: (shipment.origin_gross_weight * (1 - loss)).round,
                         destination_sacks: shipment.origin_sacks, destination_humidity_percent: shipment.origin_humidity_percent,
                         destination_damage_percent: pick([ 0, 0, 0, 0.5, 1 ]))
        next if @random.rand < 0.1 # a few wait for their sale

        by_pound = shipment.buyer.kind != "processor"
        price = price(shipment.coffee_state, date) + @random.rand(4..9)
        result = SaleIssuer.new(buyer: shipment.buyer, user: pick(@clerks), shipment_ids: [ shipment.id ],
                                sale: { sold_on: on, price_unit: by_pound ? "pound" : "quintal", unit_price: by_pound ? price : price * 100,
                                        buyer_document_number: "Doc-#{shipment.number}" }).call
        next unless result.success?

        @to_collect << result.sale
        @counts[:sales] += 1
      end
    end

    # Buyers pay some days after the sale; a few in two parts.
    def collect_sales(date)
      @to_collect.reject! do |sale|
        next false if @random.rand > ((date - sale.sold_on).to_i <= 3 ? 0.1 : 0.25)

        method = weighted("transfer" => 7, "check" => 2, "cash" => 1)
        if sale.payments.empty? && @random.rand < 0.2
          sale.payments.create!(amount: (sale.total / 2).round(2), paid_on: date, payment_method: method, created_by: pick(@clerks))
          next false
        end
        sale.payments.create!(amount: sale.reload.balance_due, paid_on: date, payment_method: method, created_by: pick(@clerks))
      end
    end

    # The business's own expenses, a few a week, and now and then an investment.
    def spend_business(date)
      return if date.sunday? || @random.rand > 0.45

      top, children = @business_categories.to_a.sample(random: @random)
      category, cost = children.to_a.sample(random: @random)
      method = weighted("cash" => 6, "transfer" => 3, "check" => 1)
      Expense.create!(kind: "expense", category:, description: "#{category.name} (#{top.name.downcase})", payee: pick([ "Proveedor Demo", "Comercial Demo", nil ]),
                      amount: (cost * (0.6 + @random.rand * 0.8)).round(2), spent_on: date, payment_method: method,
                      money_account: MoneyAccount.default_for(method), created_by: pick(@clerks))
      @counts[:expenses] += 1
      return unless date.day == 15 && @random.rand < 0.3 && (investment = INVESTMENTS[@counts[:investments]])

      category = FinanceCategory.find_or_create_by!(name: investment.first, kind: "investment", parent: nil)
      Expense.create!(kind: "investment", category:, description: investment.second, amount: investment.third, spent_on: date,
                      payment_method: "transfer", money_account: MoneyAccount.default_for("transfer"), created_by: @user)
      @counts[:investments] += 1
    end

    # A monthly budget for every first-level category, and every payment of
    # the year on the account of its method.
    def budget_and_accounts
      months = (@from.beginning_of_month..@to).map(&:beginning_of_month).uniq
      @business_categories.each do |top, children|
        amount = (children.values.sum * 4).round(-2)
        months.each { |month| Budget.find_or_create_by!(category: top, month:) { |budget| budget.amount = amount } }
      end
      cash, bank = @accounts
      [ InvoicePayment, HaulerPayment, LoanPayment, SalePayment ].each do |model|
        model.where(money_account_id: nil, payment_method: "cash").update_all(money_account_id: cash.id)
        model.where(money_account_id: nil, payment_method: %w[transfer check]).update_all(money_account_id: bank.id)
      end
      Loan.where(money_account_id: nil).where("cash_amount > 0").update_all(money_account_id: cash.id)
      PayrollPayment.where(money_account_id: nil).update_all(money_account_id: cash.id)
      PayrollExpense.where(money_account_id: nil).update_all(money_account_id: cash.id)
    end

    # Cash payments on loans, about once a month; some never pay.
    def collect(date)
      return if date.sunday?

      # By position, not by id: ids change from run to run, the same seed must give the same year.
      Loan.unpaid.where(disbursed_on: ...date).order(:id).to_a.each_with_index do |loan, index|
        next unless (index % 26) == (date.day % 26)
        next if @bad_payers&.include?(loan.id) && @random.rand < 0.85

        owed = loan.balance(as_of: date).total_owed
        amount = owed < 600 || @random.rand < 0.08 ? owed : (owed * (0.08 + @random.rand * 0.22)).round(2)
        next unless amount.positive?

        loan.payments.create!(paid_on: date, amount:, payment_method: weighted("cash" => 6, "transfer" => 3, "check" => 1),
                              created_by: pick(@clerks))
        @counts[:loan_payments] += 1
      end
    end

    # --- Farms ----------------------------------------------------------

    def work(date)
      @farms.each do |farm|
        farm[:payrolls].each do |payroll|
          next unless payroll.starts_on <= date && (payroll.ends_on.nil? || date <= payroll.ends_on)

          record_work(payroll, date) unless date.sunday?
          pay_due_period(payroll, date)
        end
        spend(farm, date)
      end
    end

    def record_work(payroll, date)
      case payroll.kind
      when "daily" then members(payroll).each { |member| attend(member, date, 0.88) }
      when "harvest" then pick_coffee(payroll, date)
      when "task" then task(payroll, date)
      end
    end

    def attend(member, date, chance)
      return if @random.rand > chance

      PayrollAttendance.create!(member:, worked_on: date, day_fraction: @random.rand < 0.12 ? 0.5 : 1)
      @counts[:attendances] += 1
    end

    def pick_coffee(payroll, date)
      good_day = CANS_A_DAY.fetch(date.month, 5)
      members(payroll).each do |member|
        next attend(member, date, 0.97) if member.paid_by_day?
        next if @random.rand > 0.82

        skill = 0.55 + (member.id % 9) * 0.11
        cans = [ (good_day * skill * (0.7 + @random.rand * 0.6) * 4).round / 4.0, 1 ].max
        HarvestEntry.create!(member:, worked_on: date, cans:)
        @counts[:harvest_entries] += 1
      end
    end

    # A task now and then, done by two to five of the crew.
    def task(payroll, date)
      return unless @random.rand < 0.12

      crew = members(payroll).sample(@random.rand(2..5), random: @random)
      payroll.tasks.create!(name: pick([ "Chapia del lote %d", "Poda del lote %d", "Reparar cerco del lote %d", "Limpieza de drenajes del lote %d",
                                         "Siembra de sombra en el lote %d" ]) % @random.rand(1..8),
                            amount: @random.rand(6..30) * 100, member_ids: crew.map(&:id), completed_on: date)
      @counts[:tasks] += 1
    end

    # A period is paid on its last day. A member who owes has part of the
    # pay go to the loan.
    def pay_due_period(payroll, date)
      period = payroll.period_containing(date)
      return unless period&.ends_on == date && payroll.payment_for(period).nil?

      lines = payroll.calculation(period).lines
      return if lines.empty?

      amounts = {}
      lines.each do |line|
        loan = line.member.person.loans.unpaid.where(disbursed_on: ..date).order(:due_on).first or next
        next if @random.rand < 0.4

        amount = [ (line.gross_amount * pick([ 0.1, 0.15, 0.2 ])).round(2), loan.balance(as_of: date).total_owed ].min
        amounts[loan.id] = amount if amount.positive?
      end
      issuer = PayrollPaymentIssuer.new(payroll:, period:, user: @user, paid_on: date, loan_amounts: amounts, with_loans: amounts.any?)
      issuer.save ? @counts[:payroll_payments] += 1 : @counts[:payroll_payment_errors] += 1
      payroll.payments.reset
    end

    # Expenses of the picking go to the harvest payroll; the rest to
    # maintenance.
    def spend(farm, date)
      return unless @random.rand < 0.28

      active = farm[:payrolls].select { |payroll| payroll.starts_on <= date && (payroll.ends_on.nil? || date <= payroll.ends_on) }
      harvest = active.find(&:harvest?)
      category = weighted(harvest ? { "Transporte" => 4, "Alimentación" => 3, "Herramientas" => 2, "Combustible" => 2 } :
                                    { "Mantenimiento" => 3, "Fertilizantes" => 3, "Combustible" => 2, "Herramientas" => 2, "Transporte" => 1 })
      payroll = (harvest if %w[Transporte Alimentación Herramientas].include?(category)) || active.find(&:daily?) || active.first or return
      payroll.expenses.create!(category: @categories.fetch(category), spent_on: date, description: pick(EXPENSES.fetch(category)),
                               amount: @random.rand(3..60) * 50, created_by: pick(@clerks))
      @counts[:expenses] += 1
    end

    def members(payroll)
      @members ||= {}
      @members[payroll.id] ||= payroll.members.includes(:role, :person).to_a
    end

    # --- Chance ---------------------------------------------------------

    def pick(list) = list.sample(random: @random)

    # A key of { key => weight }, at random by weight.
    def weighted(weights)
      roll = @random.rand * weights.values.sum
      weights.each do |key, weight|
        return key if (roll -= weight) <= 0
      end
      weights.keys.last
    end

    def weighted_producer(date)
      active = @producers.select { |plan| plan.from <= date && (plan.until.nil? || date <= plan.until) }
      return if active.empty?

      roll = @random.rand * active.sum(&:weight)
      active.find { |plan| (roll -= plan.weight) <= 0 } || active.last
    end
end
