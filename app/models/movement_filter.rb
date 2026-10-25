# The single ledger of Control financiero (Finanzas → Movimientos): every
# movement of money of every module (MoneyMovements) between two dates,
# this month by default, newest first by date and time (the filters stay
# by day). With an account, only its movements, transfers
# included, and the balance after each one; without one, transfers are
# left out (the money stays in the business).
class MovementFilter < ListFilter
  NONE = "none".freeze
  DIRECTIONS = %w[in out].freeze

  field :from, :date, default: -> { Time.zone.today.beginning_of_month }
  field :to, :date, default: -> { Time.zone.today }
  field :q, :text
  field :account, :text
  field :source, :choice, in: MoneyMovements::SOURCES
  field :direction, :choice, in: DIRECTIONS

  # The date with its time (MoneyMovements::Movement#at).
  sorts date: { ruby: ->(row) { row.movement.at } },
        source: { ruby: ->(row) { I18n.t("reports.types.cash_movements.sources.#{row.movement.source}") } },
        description: { ruby: ->(row) { row.movement.description } },
        person: { ruby: ->(row) { row.movement.person } },
        category: { ruby: ->(row) { row.movement.category } },
        account: { ruby: ->(row) { row.account_name } },
        amount_in: { ruby: ->(row) { row.movement.amount_in.positive? ? row.movement.amount_in : nil } },
        amount_out: { ruby: ->(row) { row.movement.amount_out.positive? ? row.movement.amount_out : nil } },
        balance: { ruby: ->(row) { row.balance } }

  # A movement as the list shows it: with its account's name and, when an
  # account is chosen, the balance after it.
  Row = Data.define(:movement, :balance) do
    delegate_missing_to :movement
  end

  attr_writer :user, :fixed_account

  # The account chosen: an id, :none, or nil (all).
  def account_id
    value = @fixed_account || account
    return :none if value == NONE

    value.to_s.match?(/\A\d+\z/) ? value.to_i : nil
  end

  def chosen_account = (id = account_id).is_a?(Integer) ? MoneyAccount.find_by(id:) : nil

  # The balance of the chosen account at the end of the day before `from`.
  def opening_balance
    account = chosen_account
    return unless account

    from ? AccountBalance.new(as_of: from - 1).for(account) : account.opening_balance
  end

  def movements
    @movements ||= begin
      list = MoneyMovements.new(range: from || to ? (from..to) : nil, account: account_id,
                                sources: MoneyMovements.sources_for(@user)).all
      list = list.reject(&:transfer?) if account_id.nil?
      list = list.select { |movement| movement.source == source } if source
      list = list.select { |movement| movement.direction == direction } if direction
      if q
        text = I18n.transliterate(q).downcase
        list = list.select { |movement| [ movement.description, movement.person, movement.category ].compact.any? { I18n.transliterate(it).downcase.include?(text) } }
      end
      list
    end
  end

  def total_in = movements.sum(0.to_d, &:amount_in)
  def total_out = movements.sum(0.to_d, &:amount_out)

  # Newest first, each with the balance after it when an account is chosen.
  def apply(_scope)
    running = opening_balance
    rows = movements.map do |movement|
      running += movement.net if running
      Row.new(movement:, balance: running)
    end
    rows.reverse
  end
end
