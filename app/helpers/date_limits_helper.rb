# The latest date a form accepts: today (Fernando, 2026-11-18: nothing is
# dated in the future; NotInFutureValidator says the same on the server).
module DateLimitsHelper
  def latest_date = Time.zone.today
  def latest_datetime = "#{Time.zone.today.iso8601}T23:59"
end
