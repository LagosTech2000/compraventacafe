# Reads an ISO date from params, falling back to today on absence or garbage.
module DateParam
  private
    def date_param(key = :date)
      Date.iso8601(params[key].to_s)
    rescue Date::Error
      Time.zone.today
    end
end
