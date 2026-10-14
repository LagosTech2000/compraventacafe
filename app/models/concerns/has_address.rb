# Convention for every address in the system: department, municipality and a
# free-text line. The model needs `department_id`, `municipality_id` and
# `address_line` columns; the form uses the shared/address_fields partial.
# Named HasAddress, not Addressable: that is the URI gem (loaded by Capybara).
#
# Where it is on a map (Fernando, 2026-10-13): optional `latitude` and
# `longitude`, picked on the map of the same partial; both or neither.
module HasAddress
  extend ActiveSupport::Concern

  ADDRESS_LINE_MAX = 500

  included do
    belongs_to :department, optional: true
    belongs_to :municipality, optional: true

    normalizes :address_line, with: FieldFormats::STRIP

    validates :address_line, length: { maximum: ADDRESS_LINE_MAX }
    validate :municipality_belongs_to_department
    validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
    validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
    validate :both_coordinates
  end

  def located? = latitude.present? && longitude.present?

  def address_parts
    [ address_line, municipality&.name, department&.name ].compact_blank
  end

  private
    def both_coordinates
      errors.add(latitude.nil? ? :latitude : :longitude, :blank) if latitude.nil? != longitude.nil?
    end

    def municipality_belongs_to_department
      return if municipality.nil?

      if department.nil?
        errors.add(:department, :blank)
      elsif municipality.department_id != department_id
        errors.add(:municipality, :not_in_department)
      end
    end
end
