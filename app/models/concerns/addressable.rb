# Convention for every address in the system: department, municipality and a
# free-text line. The model needs `department_id`, `municipality_id` and
# `address_line` columns; the form uses the shared/address_fields partial.
module Addressable
  extend ActiveSupport::Concern

  ADDRESS_LINE_MAX = 500

  included do
    belongs_to :department, optional: true
    belongs_to :municipality, optional: true

    normalizes :address_line, with: FieldFormats::STRIP

    validates :address_line, length: { maximum: ADDRESS_LINE_MAX }
    validate :municipality_belongs_to_department
  end

  def address_parts
    [ address_line, municipality&.name, department&.name ].compact_blank
  end

  private
    def municipality_belongs_to_department
      return if municipality.nil?

      if department.nil?
        errors.add(:department, :blank)
      elsif municipality.department_id != department_id
        errors.add(:municipality, :not_in_department)
      end
    end
end
