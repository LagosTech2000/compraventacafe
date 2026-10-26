# Cherry waiting to be processed (client, 2026-10-26: «el café cereza
# fresco puede deteriorarse rápidamente»): every lot of cherry still in
# stock that came in more hours ago than the site settings allow, with its
# level: a warning after `cherry_warning_hours` (12 at first), critical
# after `cherry_critical_hours` (24). Its time counts from when it came in
# (a transferred part keeps its purchase's date).
class CherryAlert
  LEVELS = %w[warning critical].freeze

  Item = Data.define(:lot, :level, :hours) do
    def critical? = level == "critical"
  end

  def self.hours
    setting = SiteSetting.current
    [ setting.cherry_warning_hours, setting.cherry_critical_hours ]
  end

  # The level of a lot of cherry (nil while it is fine, or not cherry).
  def self.level_for(lot, now: Time.current, thresholds: hours)
    return unless lot.coffee_state == "cherry"

    warning, critical = thresholds
    hours = lot.hours(now)
    if hours >= critical then "critical"
    elsif hours >= warning then "warning"
    end
  end

  def initialize(lots: CoffeeLots.new, warehouse_id: nil, now: Time.current)
    @lots = lots
    @warehouse_id = warehouse_id
    @now = now
  end

  # The oldest first (they are the ones to process first).
  def items
    @items ||= begin
      thresholds = self.class.hours
      @lots.lots(coffee_state: "cherry", warehouse_id: @warehouse_id).filter_map do |lot|
        level = self.class.level_for(lot, now: @now, thresholds:)
        Item.new(lot:, level:, hours: lot.hours(@now)) if level
      end
    end
  end

  def any? = items.any?
  def critical = items.select(&:critical?)
  def level = critical.any? ? "critical" : ("warning" if any?)
  def net = items.sum(0.to_d) { it.lot.net }
end
