# The Christmas season (Fernando, 2026-11-15: «un tema navideño muy gentil,
# desde el 15 de noviembre, todo diciembre y la primera semana de enero»):
# while it lasts, a few small decorations show (body.christmas in the
# layout, HolidayHelper). Nothing else changes.
module HolidaySeason
  def self.christmas?(date = Time.zone.today)
    (date.month == 11 && date.day >= 15) || date.month == 12 || (date.month == 1 && date.day <= 7)
  end
end
