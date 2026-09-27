# Role of a Person: someone the business buys coffee from.
class Producer < ApplicationRecord
  include Auditable

  KINDS = %w[producer intermediary own_farm].freeze

  belongs_to :person
  accepts_nested_attributes_for :person
  belongs_to :zone, optional: true
  has_many :purchases, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error

  normalizes :farm_name, with: FieldFormats::STRIP

  validates :kind, inclusion: { in: KINDS }
  validates :farm_name, length: { maximum: 100 }

  delegate :full_name, to: :person

  scope :alphabetical, -> { joins(:person).merge(Person.alphabetical) }

  def audit_label
    person.full_name
  end

  # How the purchase form's producer search lists this producer.
  def picker_label
    [ full_name, person.dni ].compact.join(" — ")
  end

  def human_kind
    self.class.human_attribute_name("kind/#{kind}")
  end
end
