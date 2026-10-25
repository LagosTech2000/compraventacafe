module Finance
  # The payroll sheet of the Planilla interna (StaffSheet): the fortnight
  # with its attendance, the month and the history; attendance is saved
  # here and the fortnight's due periods can be paid together.
  class StaffSheetsController < ApplicationController
    before_action :set_sheet

    def show
      authorize [ :finance, :staff_sheet ]
    end

    # Attendance of the fortnight: work[member_id][date] = "1", "0.5" or "".
    # Only what changed is written; all of it or nothing.
    def update
      authorize [ :finance, :staff_sheet ], :update?
      error = save_attendance
      if error
        redirect_to sheet_path, alert: error
      else
        redirect_to sheet_path, notice: t(".success")
      end
    end

    # Pays the marked employees' period of this fortnight, with the same
    # date, method and account; each one apart, saying who could not.
    def pay
      authorize [ :finance, :staff_sheet ], :pay?
      chosen = Array(params[:member_ids]).map(&:to_i)
      paid = []
      failed = []
      @sheet.payable_rows.select { chosen.include?(it.member.id) }.each do |row|
        issuer = StaffPaymentIssuer.new(member: row.member, period: row.period, user: Current.user, paid_on: paid_on,
                                        payment_method: params[:payment_method], money_account_id: params[:money_account_id])
        if issuer.call
          paid << row.member.full_name
        else
          failed << "#{row.member.full_name}: #{issuer.payment.errors.full_messages.to_sentence}"
        end
      end
      flash[:notice] = t(".success", count: paid.size) if paid.any? || failed.empty?
      flash[:alert] = t(".failed", list: failed.join("; ")) if failed.any?
      redirect_to sheet_path
    end

    private
      def set_sheet
        @sheet = StaffSheet.new(view: params[:view], month: params[:month], half: params[:half], season_year: params[:season_year])
      end

      def sheet_path = finance_staff_sheet_path(view: "fortnight", month: @sheet.month.strftime("%Y-%m"), half: @sheet.half)

      def paid_on = parse_date(params[:paid_on]) || Time.zone.today

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end

      def save_attendance
        work = params.fetch(:work, {})
        members = @sheet.members.index_by { it.id.to_s }
        StaffAttendance.transaction do
          work.each_pair do |member_id, days|
            member = members[member_id.to_s] or next
            days.each_pair do |date, value|
              date = parse_date(date)
              next unless date && @sheet.fortnight.cover?(date)

              save_day(member, date, value.to_s)
            end
          end
        end
        nil
      rescue ActiveRecord::RecordInvalid => error
        "#{error.record.member.full_name}, #{I18n.l(error.record.worked_on)}: #{error.record.errors.full_messages.to_sentence}"
      end

      def save_day(member, date, value)
        current = member.attendances.find { it.worked_on == date }
        # "1" or "0.5"; anything else (blank) means absent.
        fraction = StaffAttendance::FRACTIONS.find { it == value.to_d }
        if fraction.nil?
          current&.destroy!
        elsif current.nil?
          member.attendances.create!(worked_on: date, day_fraction: fraction)
        elsif current.day_fraction != fraction
          current.update!(day_fraction: fraction)
        end
      end
  end
end
