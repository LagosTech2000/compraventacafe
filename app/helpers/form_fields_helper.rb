# Convention helpers so every form validates the same way as its model.
module FormFieldsHelper
  # HTML attributes for a field backed by a FieldFormats entry.
  #   form.text_field :dni, **field_format_attributes(Person, :dni, :dni)
  def field_format_attributes(model_class, attribute, format_name, required: false)
    format = FieldFormats.fetch(format_name)
    label = model_class.human_attribute_name(attribute)

    {
      pattern: format.html_pattern,
      maxlength: format.maxlength,
      inputmode: format.inputmode,
      required: required || nil,
      data: {
        invalid_message: "#{label} #{t("errors.messages.#{format.message}")}",
        missing_message: ("#{label} #{t("errors.messages.blank")}" if required)
      }.compact
    }.compact
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
end
