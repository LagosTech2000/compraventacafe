# validates :dni, field_format: :dni
class FieldFormatValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    format = FieldFormats.fetch(options[:with])
    record.errors.add(attribute, format.message) unless format.pattern.match?(value.to_s)
  end
end
