# Producers that stopped selling (Fernando, 2026-11-13: «Productores que no
# venden hace 7 días, 15 días o un mes»): those with active purchases whose
# last one is older than that, the ones that stopped most recently first.
# Producers that never sold are not here. Only sums of what is kept.
class IdleProducers
  DAYS = [ 7, 15, 30 ].freeze
  CARD_LIMIT = 30

  def self.days(value) = DAYS.include?(value.to_i) ? value.to_i : DAYS.first

  # Producers with their last purchase (`last_purchased_at`), before the cutoff.
  def self.scope(days, now: Time.current)
    # Of the user's own purchases when they see only theirs (OwnedRecord).
    last = Purchase.owned.active.group(:producer_id).select("purchases.producer_id, MAX(purchases.purchased_at) AS last_purchased_at")
    Producer.joins("JOIN (#{last.to_sql}) last_purchases ON last_purchases.producer_id = producers.id")
            .where(last_purchases: { last_purchased_at: ...(now - days(days).days) })
            .select("producers.*, last_purchases.last_purchased_at")
  end

  # Days since a producer's last purchase.
  def self.days_since(producer, today: Time.zone.today) = (today - producer.last_purchased_at.in_time_zone.to_date).to_i
end
