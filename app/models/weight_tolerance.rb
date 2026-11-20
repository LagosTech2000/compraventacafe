# From what difference (%) between the local scale and the buyer's a
# shipment stands out (Fernando, 2026-10-23). Set by admins in the site
# settings; empty at first, and then no shipment stands out.
#
# And from what shrink (%) between its lots' purchases and its local scale
# (Fernando, 2026-11-18). Passing either one asks for a reason, never
# blocks (Shipment#reasons_given).
module WeightTolerance
  NONE = :none

  # The percent, or nil. Read once per request.
  def self.percent
    Current.weight_tolerance ||= SiteSetting.current.weight_tolerance_percent || NONE
    Current.weight_tolerance == NONE ? nil : Current.weight_tolerance
  end

  def self.shrink_percent
    Current.shrink_tolerance ||= SiteSetting.current.shrink_tolerance_percent || NONE
    Current.shrink_tolerance == NONE ? nil : Current.shrink_tolerance
  end
end
