# Role of a Person: someone the business buys coffee from.
class Producer < ApplicationRecord
  include Auditable

  KINDS = %w[producer intermediary own_farm].freeze

  belongs_to :person, inverse_of: :producer
  accepts_nested_attributes_for :person
  # The zone is the person's (every person form has it).
  has_one :zone, through: :person
  has_many :purchases, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error
  # The producer's own farms, which their purchases can name.
  has_many :farms, -> { order(:name) }, dependent: :restrict_with_error

  # Farms written in the form (one or several): each assigned if the
  # producer has it (any case), created otherwise (Farm.for_producer),
  # after saving.
  attribute :new_farm_name, :string
  attr_accessor :new_farm_names
  after_save :add_new_farms

  normalizes :ihcafe_code, with: FieldFormats::IHCAFE_CODE

  validates :kind, inclusion: { in: KINDS }
  validates :new_farm_name, length: { maximum: 100 }
  validate :new_farm_names_length
  # Optional (intermediaries may not have one), unique when given.
  validates :ihcafe_code, field_format: :ihcafe_code, uniqueness: true, allow_nil: true

  delegate :full_name, :zone_id, to: :person

  scope :alphabetical, -> { joins(:person).merge(Person.alphabetical) }

  def audit_label
    person.full_name
  end

  # How the purchase form's producer search lists this producer.
  def picker_label
    [ full_name, person.dni ].compact.join(" — ")
  end

  def farm_names = farms.map(&:name).join(", ")

  # The details of its record still empty, by name, for the purchase form to
  # point them out. Only says what is blank; none of them is required.
  def missing_fields
    fields = %i[dni rtn phone email zone_id].select { |field| person.public_send(field).blank? }
                                             .map { |field| Person.human_attribute_name(field) }
    fields << I18n.t("addresses.title") if [ person.department_id, person.municipality_id, person.address_line ].any?(&:blank?)
    fields << self.class.human_attribute_name(:ihcafe_code) if ihcafe_code.blank?
    fields
  end

  def human_kind
    self.class.human_attribute_name("kind/#{kind}")
  end

  private
    def new_farm_names_length
      errors.add(:new_farm_names, :too_long, count: 100) if Array(new_farm_names).any? { |name| name.to_s.length > 100 }
    end

    def add_new_farms
      [ new_farm_name, *Array(new_farm_names) ].compact_blank.uniq { |name| name.squish.downcase }
                                              .each { |name| Farm.for_producer(self, name) }
      self.new_farm_name = nil
      self.new_farm_names = nil
    end
end
