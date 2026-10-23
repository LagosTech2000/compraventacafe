# The work of a pay period as grids of members × days: attendance (full or
# half day) for members paid by day, cans picked for the pickers of a
# harvest payroll (its foremen are paid by day). Members paid by day also
# have, at the end of their row, the period's extra hours and extra days
# (PayrollOvertime). Saving it creates, changes or removes the day records
# and the overtime, all or nothing. A paid period is closed.
class PayrollTimesheet
  include ActiveModel::Model

  attr_reader :payroll, :period

  def self.model_name = ActiveModel::Name.new(self, nil, "PayrollTimesheet")

  def initialize(payroll, period)
    @payroll = payroll
    @period = period
  end

  def harvest? = payroll.harvest?
  def dates = period.dates.to_a
  def members = @members ||= payroll.members_for(period)
  def payment = @payment ||= payroll.payments.find_by(period_starts_on: period.starts_on)
  def closed? = payment.present?

  # [basis, members] for each grid: pickers by cans first, then by day.
  def groups
    members.group_by(&:basis).sort_by { |basis, _| basis == "harvest" ? 0 : 1 }
  end

  # Day fraction (attendance) or cans, nil when nothing was recorded.
  def value(member, date)
    raw = @submitted&.dig(member.id.to_s, date.iso8601)
    return parse(raw) unless raw.nil?

    records[[ member.id, date ]]&.public_send(column(member))
  end

  def total_for(member)
    dates.sum { |date| value(member, date) || 0 }
  end

  def total_for_date(date, members = self.members)
    members.sum { |member| value(member, date) || 0 }
  end

  def rate_for(member) = member.paid_by_day? ? member.daily_wage : payroll.can_price

  # The value of an extra hour in this payroll (nil while not set).
  def overtime_hour_rate = payroll.overtime_hour_rate

  # Extra hours or extra days of a member paid by day in the period: what
  # was sent, or what is saved (0 without any).
  def overtime(member, field)
    raw = @submitted_overtime&.dig(member.id.to_s, field.to_s)
    return parse(raw) || 0 unless raw.nil?

    overtimes[member.id]&.public_send(field) || 0
  end

  def overtime_amount(member)
    rate = member.daily_wage.to_d
    (overtime(member, :extra_days) * rate + overtime(member, :hours) * overtime_hour_rate.to_d).round(2)
  end

  def amount_for(member)
    rate = rate_for(member)
    return unless rate

    amount = (total_for(member) * rate.to_d).round(2)
    member.paid_by_day? ? amount + overtime_amount(member) : amount
  end

  # values: { "member_id" => { "2026-10-05" => "1" } }; only the cells sent
  # are touched. Blank or 0 removes the day.
  # overtime: { "member_id" => { "hours" => "3", "extra_days" => "1" } }
  # for members paid by day; both blank or 0 remove it.
  def update(values, overtime = {})
    @submitted = values.to_h.transform_values(&:to_h)
    @submitted_overtime = overtime.to_h.transform_values(&:to_h)
    errors.add(:base, :closed) and return false if closed?

    ActiveRecord::Base.transaction do
      # Days removed first: a day moved from one role of a person to
      # another (PayrollAttendance#day_free_in_other_roles) frees it before
      # it is taken.
      cells = members.flat_map do |member|
        dates.filter_map do |date|
          raw = @submitted.dig(member.id.to_s, date.iso8601)
          [ member, date, raw ] unless raw.nil?
        end
      end
      cells.sort_by { |_, _, raw| parse(raw).to_d.zero? ? 0 : 1 }.each { |member, date, raw| save_cell(member, date, raw) }
      members.each do |member|
        save_overtime(member) if member.paid_by_day? && @submitted_overtime.key?(member.id.to_s)
      end
      raise ActiveRecord::Rollback if errors.any?
    end
    errors.empty?
  end

  private
    def column(member) = member.paid_by_day? ? :day_fraction : :cans
    def model(member) = member.paid_by_day? ? PayrollAttendance : HarvestEntry

    def records
      @records ||= [ PayrollAttendance, HarvestEntry ].flat_map do |model|
        model.where(payroll_member_id: members.map(&:id), worked_on: period.dates).to_a
      end.index_by { |record| [ record.payroll_member_id, record.worked_on ] }
    end

    def overtimes
      @overtimes ||= PayrollOvertime.where(payroll_member_id: members.map(&:id), period_starts_on: period.starts_on)
                                    .index_by(&:payroll_member_id)
    end

    def save_overtime(member)
      sent = @submitted_overtime.fetch(member.id.to_s)
      hours = sent.key?("hours") ? parse(sent["hours"]) : overtimes[member.id]&.hours
      extra_days = sent.key?("extra_days") ? parse(sent["extra_days"]) : overtimes[member.id]&.extra_days
      record = overtimes[member.id] || PayrollOvertime.new(member:, period_starts_on: period.starts_on)
      record.assign_attributes(hours: hours || 0, extra_days: extra_days || 0)
      if record.empty?
        record.destroy! if record.persisted?
      elsif record.changed?
        record.save || record.errors.full_messages.each do |message|
          errors.add(:base, :overtime, person: member.full_name, detail: message)
        end
      end
    end

    def save_cell(member, date, raw)
      quantity = parse(raw)
      record = records[[ member.id, date ]]
      if quantity.nil? || quantity.zero?
        record&.destroy!
      elsif record
        record.update(column(member) => quantity) || copy_errors(record, member, date)
      else
        record = model(member).new(member:, worked_on: date, column(member) => quantity)
        record.save || copy_errors(record, member, date)
      end
    end

    def copy_errors(record, member, date)
      record.errors.full_messages.each do |message|
        errors.add(:base, :cell, person: member.label, date: I18n.l(date, format: :short_day), detail: message)
      end
    end

    def parse(raw)
      text = raw.to_s.strip.delete(",")
      BigDecimal(text) unless text.empty?
    rescue ArgumentError
      BigDecimal("-1")
    end
end
