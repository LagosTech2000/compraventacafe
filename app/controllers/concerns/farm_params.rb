# What a farm form sends, from the Fincas module or from Administración.
# Its producer can change while no purchase or payroll names the farm
# (Farm#owner_locked?).
module FarmParams
  private
    def farm_params
      params.expect(farm: [ :name, :producer_id, :department_id, :municipality_id, :address_line, :latitude, :longitude,
                            :area_value, :area_unit, :observations, :active ])
    end

    # What a form that picks the farm (a purchase) learns when it is saved in
    # the modal ("farm:created", "farm:updated"): its name and what it still
    # misses (Farm#missing_fields).
    def farm_picker_detail(farm)
      { id: farm.id, name: farm.name, producer_id: farm.producer_id, missing: farm.missing_fields }
    end
end
