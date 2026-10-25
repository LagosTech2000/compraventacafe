# From what difference (%) between the local scale and the buyer's a
# shipment stands out (Fernando, 2026-10-23). Set by admins in the site
# settings; empty at first, and then no shipment stands out.
module WeightTolerance
  NONE = :none

  # The percent, or nil. Read once per request.
  def self.percent
    Current.weight_tolerance ||= SiteSetting.current.weight_tolerance_percent || NONE
    Current.weight_tolerance == NONE ? nil : Current.weight_tolerance
  end
end
