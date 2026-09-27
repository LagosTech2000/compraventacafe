# Identity and contact, stored once. Client and Collaborator are roles on top.
# dni (13 digits) and rtn (14 digits) are unique per person and optional.
class Person < ApplicationRecord
  include Addressable
  include Auditable

  has_one :client, dependent: :destroy, autosave: true
  has_one :collaborator, dependent: :destroy, autosave: true
  has_one :producer, dependent: :restrict_with_error

  normalizes :first_names, :last_names, with: ->(value) { value.squish.presence }
  normalizes :dni, :rtn, with: FieldFormats::DIGITS
  normalizes :phone, with: FieldFormats::PHONE
  normalizes :email, with: FieldFormats::EMAIL

  validates :first_names, :last_names, presence: true, field_format: :person_name, length: { maximum: 100 }
  validates :dni, field_format: :dni, uniqueness: true, allow_nil: true
  validates :rtn, field_format: :rtn, uniqueness: true, allow_nil: true
  validates :phone, field_format: :phone
  validates :email, field_format: :email, length: { maximum: 254 }

  scope :alphabetical, -> { order(:last_names, :first_names) }
  scope :search, ->(term) {
    pattern = "%#{sanitize_sql_like(term.strip)}%"
    where("first_names ILIKE :p OR last_names ILIKE :p OR dni ILIKE :p OR rtn ILIKE :p", p: pattern)
  }
  scope :clients, -> { joins(:client) }
  scope :collaborators, -> { joins(:collaborator) }
  scope :producers, -> { joins(:producer) }

  def full_name
    "#{first_names} #{last_names}"
  end

  alias_method :audit_label, :full_name

  def client?
    client.present?
  end

  def collaborator?
    collaborator.present?
  end

  def producer?
    producer.present?
  end

  # Adds or removes each role from a form checkbox.
  def assign_roles(client:, collaborator:)
    toggle_role(:client, client)
    toggle_role(:collaborator, collaborator)
  end

  private
    def toggle_role(role, wanted)
      wanted = ActiveModel::Type::Boolean.new.cast(wanted)
      current = public_send(role)

      if wanted && current.nil?
        public_send("build_#{role}")
      elsif !wanted && current
        current.mark_for_destruction
      end
    end
end
