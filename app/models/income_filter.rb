# Control financiero → Ingresos (Fernando, 2026-10-24): every peso that came
# in, from the modules the user reads: collections of coffee sales, loan
# payments in money and other income (MoneyMovements), between two dates,
# this month by default, newest first. Transfers between accounts are not
# income: the money stays home.
class IncomeFilter < ListFilter
  SOURCES = %w[sale_payments loan_payments other_incomes].freeze

  field :from, :date, default: -> { Time.zone.today.beginning_of_month }
  field :to, :date, default: -> { Time.zone.today }
  field :q, :text
  field :account, :text
  field :source, :choice, in: SOURCES

  sorts date: { ruby: ->(movement) { movement.at } },
        source: { ruby: ->(movement) { I18n.t("reports.types.cash_movements.sources.#{movement.source}") } },
        description: { ruby: ->(movement) { movement.description } },
        person: { ruby: ->(movement) { movement.person } },
        account: { ruby: ->(movement) { movement.account_name } },
        amount: { ruby: ->(movement) { movement.amount_in } }

  attr_writer :user

  # The sources this user may read.
  def sources = SOURCES & MoneyMovements.sources_for(@user)

  # An account id, :none (without one) or nil (any).
  def account_id
    return :none if account == MovementFilter::NONE

    account.to_s.match?(/\A\d+\z/) ? account.to_i : nil
  end

  def incomes
    @incomes ||= begin
      list = MoneyMovements.new(range: from || to ? (from..to) : nil, account: account_id,
                                sources: source ? sources & [ source ] : sources).all
      if q
        text = I18n.transliterate(q).downcase
        list = list.select { |movement| [ movement.description, movement.person ].compact.any? { I18n.transliterate(it).downcase.include?(text) } }
      end
      list
    end
  end

  def total = incomes.sum(0.to_d, &:amount_in)

  # { "sale_payments" => 1_000, ... }, for each source the user reads.
  def totals_by_source
    sums = incomes.group_by(&:source).transform_values { |list| list.sum(0.to_d, &:amount_in) }
    sources.index_with { sums.fetch(it, 0.to_d) }
  end

  def apply(_scope) = incomes.reverse
end
