# What a farm form sends, from the Fincas module or from Administración.
# Its producer can change while no purchase or payroll names the farm
# (Farm#owner_locked?).
module FarmParams
  private
    def farm_params
      params.expect(farm: [ :name, :producer_id, :department_id, :municipality_id, :address_line, :latitude, :longitude,
                            :area_value, :area_unit, :observations, :active ])
    end
end
