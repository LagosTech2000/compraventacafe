# Control financiero → Consolidación: the movements registered without an
# account (MoneyMovements with account :none), of the sources an account
# can be given to, newest first. All dates unless chosen; also by payment
# method, in or out, and an amount between two figures (Fernando,
# 2026-10-24).
class ConsolidationFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :source, :choice, in: AccountConsolidation::SOURCES
  field :payment_method, :choice, in: Invoice::PAYMENT_METHODS
  field :direction, :choice, in: MovementFilter::DIRECTIONS
  field :amount_min, :text
  field :amount_max, :text

  sorts date: { ruby: ->(movement) { movement.at } },
        source: { ruby: ->(movement) { I18n.t("reports.types.cash_movements.sources.#{movement.source}") } },
        description: { ruby: ->(movement) { movement.description } },
        person: { ruby: ->(movement) { movement.person } },
        payment_method: { ruby: ->(movement) { movement.payment_method } },
        category: { ruby: ->(movement) { movement.category } },
        amount_in: { ruby: ->(movement) { movement.amount_in.positive? ? movement.amount_in : nil } },
        amount_out: { ruby: ->(movement) { movement.amount_out.positive? ? movement.amount_out : nil } }

  attr_writer :user

  def sources = AccountConsolidation::SOURCES & MoneyMovements.sources_for(@user)

  def movements
    @movements ||= begin
      list = MoneyMovements.new(range: from || to ? (from..to) : nil, account: :none, sources: source ? [ source ] & sources : sources).all
      if q
        text = I18n.transliterate(q).downcase
        list = list.select { |movement| [ movement.description, movement.person ].compact.any? { I18n.transliterate(it).downcase.include?(text) } }
      end
      list = list.select { |movement| movement.payment_method == method_label } if payment_method
      list = list.select { |movement| movement.direction == direction } if direction
      list = list.select { |movement| amount(movement) >= minimum } if minimum
      list = list.select { |movement| amount(movement) <= maximum } if maximum
      list
    end
  end

  def apply(_scope) = movements.reverse

  # The amounts typed, as numbers (anything else is ignored).
  def minimum = number(amount_min)
  def maximum = number(amount_max)

  private
    def method_label = Invoice.human_attribute_name("payment_method/#{payment_method}")
    def amount(movement) = movement.amount_in + movement.amount_out

    def number(value)
      text = value.to_s.delete(",").strip
      BigDecimal(text) if text.match?(/\A\d+(\.\d+)?\z/)
    end
end
