# Convention helpers so every form validates the same way as its model.
module FormFieldsHelper
  # HTML attributes for a field backed by a FieldFormats entry.
  #   form.text_field :dni, **field_format_attributes(Person, :dni, :dni)
  def field_format_attributes(model_class, attribute, format_name, required: false)
    format = FieldFormats.fetch(format_name)
    label = model_class.human_attribute_name(attribute)

    {
      pattern: format.html_pattern,
      minlength: format.minlength,
      maxlength: format.maxlength,
      inputmode: format.inputmode,
      required: required || nil,
      data: {
        invalid_message: "#{label} #{t("errors.messages.#{format.message}")}",
        missing_message: ("#{label} #{t("errors.messages.blank")}" if required)
      }.compact
    }.compact
  end

  # A confirmation field that must equal another field of the same form.
  #   form.password_field :password_confirmation, **confirmation_attributes(User, :password_confirmation, form.field_id(:password))
  def confirmation_attributes(model_class, attribute, confirms_field_id)
    label = model_class.human_attribute_name(attribute)
    {
      required: true,
      data: {
        must_match: confirms_field_id,
        mismatch_message: "#{label} #{t("errors.messages.confirmation", attribute: model_class.human_attribute_name(attribute.to_s.delete_suffix("_confirmation")))}",
        missing_message: "#{label} #{t("errors.messages.blank")}"
      }
    }
  end

  # Full messages, naming nested attributes ("person.first_names") with the
  # associated model's translation instead of a humanized English key.
  def form_error_messages(record)
    record.errors.map do |error|
      association, attribute = error.attribute.to_s.split(".", 2)
      reflection = attribute && record.class.reflect_on_association(association)
      next error.full_message unless reflection

      t("errors.format", attribute: reflection.klass.human_attribute_name(attribute), message: error.message)
    end.uniq
  end

  # { department_id => [[municipality_id, name], ...] } for the address picker.
  def municipalities_by_department
    @municipalities_by_department ||= Municipality.order(:name).pluck(:department_id, :id, :name)
      .group_by(&:first).transform_values { |rows| rows.map { |_, id, name| [ id, name ] } }
  end

  def format_phone(phone)
    phone.to_s.match?(/\A\d{8}\z/) ? "#{phone[0, 4]}-#{phone[4, 4]}" : phone
  end

  def format_address(record)
    record.address_parts.join(", ")
  end

  # The data of a location map (location_map_controller.js): the tiles, their
  # attribution, and Honduras in view while there is no pin.
  HONDURAS_CENTER = [ 14.8, -86.8 ].freeze

  def location_map_data(readonly: false, point: nil)
    { controller: "location-map", location_map_tiles_value: Rails.configuration.x.map_tiles_url.to_s,
      location_map_attribution_value: t("addresses.map.attribution_html"), location_map_center_value: HONDURAS_CENTER.to_json,
      location_map_readonly_value: readonly, location_map_point_value: point&.to_json,
      location_map_locate_failed_value: t("addresses.map.locate_failed"), location_map_labels_value: map_labels.to_json }.compact
  end

  # Leaflet's own control names, in Spanish.
  def map_labels
    { zoom_in: t("addresses.map.zoom_in"), zoom_out: t("addresses.map.zoom_out"), close: t("addresses.map.close") }
  end
end
