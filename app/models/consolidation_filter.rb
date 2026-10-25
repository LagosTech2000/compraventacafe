# Control financiero → Consolidación: the movements registered without an
# account (MoneyMovements with account :none), of the sources an account
# can be given to, newest first. All dates unless chosen.
class ConsolidationFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :source, :choice, in: AccountConsolidation::SOURCES

  sorts date: { ruby: ->(movement) { movement.at } },
        source: { ruby: ->(movement) { I18n.t("reports.types.cash_movements.sources.#{movement.source}") } },
        description: { ruby: ->(movement) { movement.description } },
        person: { ruby: ->(movement) { movement.person } },
        payment_method: { ruby: ->(movement) { movement.payment_method } },
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
      list
    end
  end

  def apply(_scope) = movements.reverse
end
