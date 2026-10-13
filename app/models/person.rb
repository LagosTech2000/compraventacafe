# Identity and contact, stored once. Client, Collaborator and Producer are
# roles on top. dni (13 digits) and rtn (14 digits) are unique per person and
# optional. The zone the person is from is optional too.
#
# Every person form has a checkbox per role (client_role, collaborator_role,
# producer_role, with producer_kind for a new producer), and at least one
# must be checked (Fernando, 2026-10-12): the check applies whenever the
# form sent them, not to people created in code.
class Person < ApplicationRecord
  include HasAddress
  include Auditable

  ROLES = %i[client collaborator producer].freeze

  belongs_to :zone, optional: true
  has_one :client, dependent: :destroy, autosave: true
  has_one :collaborator, dependent: :destroy, autosave: true
  has_one :producer, dependent: :restrict_with_error, autosave: true
  has_many :loans, dependent: :restrict_with_error
  has_many :payroll_members, dependent: :restrict_with_error

  normalizes :first_names, :last_names, with: ->(value) { value.squish.presence }
  normalizes :dni, :rtn, with: FieldFormats::DIGITS
  normalizes :phone, with: FieldFormats::PHONE
  normalizes :email, with: FieldFormats::EMAIL

  validates :first_names, :last_names, presence: true, field_format: :person_name, length: { maximum: 100 }
  validates :dni, field_format: :dni, uniqueness: true, allow_nil: true
  validates :rtn, field_format: :rtn, uniqueness: true, allow_nil: true
  validates :phone, field_format: :phone
  validates :email, field_format: :email, length: { maximum: 254 }
  validate :role_chosen, if: :roles_from_form
  validate :producer_removable

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

  # Shown in searchable pickers: the DNI tells apart people with the same name.
  def picker_label
    [ full_name, dni ].compact.join(" — ")
  end

  def client?
    client.present?
  end

  def collaborator?
    collaborator.present?
  end

  def producer?
    producer.present?
  end

  attr_reader :roles_from_form

  # The form's checkboxes: each adds or removes its role.
  ROLES.each do |role|
    define_method(:"#{role}_role=") { |wanted| toggle_role(role, wanted) }
    define_method(:"#{role}_role") { role?(role) }
  end

  # The kind of a producer added from the form (Producer::KINDS); a producer
  # that already exists keeps its own, edited in its form.
  def producer_kind=(kind)
    @producer_kind = kind.presence
    producer.kind = @producer_kind if @producer_kind && producer&.new_record?
  end

  def producer_kind = producer&.kind || @producer_kind || "producer"

  # Has the role, and it is not being removed.
  def role?(role)
    record = public_send(role)
    record.present? && !record.marked_for_destruction?
  end

  private
    def toggle_role(role, wanted)
      @roles_from_form = true
      wanted = ActiveModel::Type::Boolean.new.cast(wanted)
      current = public_send(role)

      if wanted && current&.marked_for_destruction?
        current.reload
      elsif wanted && current.nil?
        public_send("build_#{role}", **(role == :producer ? { kind: producer_kind } : {}))
      elsif !wanted && current
        current.new_record? ? public_send("#{role}=", nil) : current.mark_for_destruction
      end
    end

    def role_chosen
      errors.add(:base, :role_required) if ROLES.none? { |role| role?(role) }
    end

    # A producer with purchases, invoices or farms stays one.
    def producer_removable
      return unless producer&.marked_for_destruction?
      return unless producer.purchases.exists? || producer.invoices.exists? || producer.farms.exists?

      errors.add(:base, :producer_in_use)
    end
end
