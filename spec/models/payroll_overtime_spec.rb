require "rails_helper"

# Overtime per pay period (Fernando, 2026-10-14): extra hours at the
# payroll's value of an extra hour, extra days at the member's daily wage,
# only for members paid by day.
RSpec.describe PayrollOvertime do
  let(:user) { create(:user) }
  let(:payroll) { create(:payroll, kind: "daily", starts_on: Date.new(2026, 9, 1), overtime_hour_rate: 50) }
  let(:member) { create(:payroll_member, payroll:) } # role at L 300 a day
  let(:period) { payroll.period_containing(Date.new(2026, 9, 1)) }

  def overtime(**attributes) = described_class.new(member:, period_starts_on: period.starts_on, **attributes)

  it "adds extra hours × the hour value and extra days × the daily wage to the period's pay, and keeps them on the payment" do
    PayrollAttendance.create!(member:, worked_on: Date.new(2026, 9, 2), day_fraction: 1)
    overtime(hours: 3, extra_days: 1).save!

    line = payroll.calculation(period).lines.sole
    expect(line.to_h.slice(:quantity, :rate, :overtime_hours, :overtime_hour_rate, :extra_days, :overtime_amount, :gross_amount))
      .to eq(quantity: 1, rate: 300, overtime_hours: 3, overtime_hour_rate: 50, extra_days: 1, overtime_amount: 450, gross_amount: 750)

    issuer = PayrollPaymentIssuer.new(payroll:, period:, user:, paid_on: period.ends_on)
    expect(issuer.save).to be(true)
    expect(issuer.payment.lines.sole).to have_attributes(overtime_hours: 3, overtime_hour_rate: 50, extra_days: 1,
                                                         overtime_amount: 450, gross_amount: 750)

    # Paid: the value can change, the payment keeps what was paid; the period is closed.
    payroll.update!(overtime_hour_rate: 80)
    expect(issuer.payment.lines.sole.reload.gross_amount).to eq(750)
    saved = described_class.last
    expect(saved.update(hours: 5)).to be(false)
    expect(saved.errors.full_messages).to include("Este período ya se pagó.")
  end

  it "pays a member with only overtime in the period" do
    overtime(extra_days: 0.5).save!
    expect(payroll.calculation(period).lines.sole.gross_amount).to eq(150)
  end

  it "needs the hour value for hours, days by halves, and members paid by day" do
    payroll.update!(overtime_hour_rate: nil)
    record = overtime(hours: 2)
    expect(record).not_to be_valid
    expect(record.errors.full_messages).to include("Horas extra no se pueden anotar: la planilla no tiene valor de la hora extra")
    expect(overtime(extra_days: 1)).to be_valid
    expect(overtime(extra_days: 0.3).tap(&:valid?).errors.full_messages).to include("Días extra van de medio en medio (0.5, 1, 1.5…)")
    expect(overtime(hours: -1).tap(&:valid?).errors[:hours]).to be_present

    harvest = create(:payroll, kind: "harvest", can_price: 25, starts_on: Date.new(2026, 9, 1), overtime_hour_rate: 40)
    picker = create(:payroll_member, payroll: harvest)
    record = described_class.new(member: picker, period_starts_on: harvest.periods.first.starts_on, hours: 1)
    expect(record.tap(&:valid?).errors.full_messages).to include("Las horas y días extra son solo para quienes ganan por día.")
  end

  it "belongs to a period of the payroll" do
    expect(described_class.new(member:, period_starts_on: Date.new(2026, 9, 3), extra_days: 1).tap(&:valid?).errors[:period_starts_on])
      .to include("no es un período de la planilla")
  end

  it "does not pay hours when the payroll lost its hour value" do
    overtime(hours: 2).save!
    payroll.update_column(:overtime_hour_rate, nil)
    issuer = PayrollPaymentIssuer.new(payroll:, period:, user:, paid_on: period.ends_on)
    expect(issuer.save).to be(false)
    expect(issuer.errors.full_messages).to include(a_string_including("no tiene valor de la hora extra"))
  end

  it "has no hour value in a payroll by task" do
    task = create(:payroll, kind: "task", starts_on: Date.new(2026, 9, 1), overtime_hour_rate: 50)
    expect(task.overtime_hour_rate).to be_nil
  end
end
