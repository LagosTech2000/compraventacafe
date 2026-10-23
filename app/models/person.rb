# Identity and contact, stored once. Client, Collaborator, Producer and
# Hauler (carrero) are roles on top. dni (13 digits) and rtn (14 digits) are unique per person and
# optional. The zone the person is from is optional too, and so are the
# civil status and nationality (the private loan contract asks for both,
# Fernando 2026-10-22).
#
# Every person form has a checkbox per role (client_role, collaborator_role,
# producer_role, with producer_kind for a new producer, and hauler_role,
# with the new hauler's commission percent and can price), and at least one
# must be checked (Fernando, 2026-10-12): the check applies whenever the
# form sent them, not to people created in code.
class Person < ApplicationRecord
  include HasAddress
  include HasPhoto
  include Auditable

  ROLES = %i[client collaborator producer hauler].freeze
  # picker_search: the names without case or Spanish accents, and with
  # digits, the DNI and RTN too. Fixed SQL: the values go as parameters.
  NAMES_MATCH = "translate(lower(people.first_names), 'áéíóúüñ', 'aeiouun') LIKE :name OR " \
                "translate(lower(people.last_names), 'áéíóúüñ', 'aeiouun') LIKE :name".freeze
  NAMES_OR_NUMBERS_MATCH = "#{NAMES_MATCH} OR people.dni LIKE :digits OR people.rtn LIKE :digits".freeze

  def self.fold(text) = text.to_s.downcase.tr("áéíóúüñ", "aeiouun")

  belongs_to :zone, optional: true
  has_one :client, dependent: :destroy, autosave: true
  has_one :collaborator, dependent: :destroy, autosave: true
  has_one :producer, dependent: :restrict_with_error, autosave: true
  has_one :hauler, dependent: :restrict_with_error, autosave: true
  has_many :loans, dependent: :restrict_with_error
  has_many :payroll_members, dependent: :restrict_with_error
  has_many :private_document_prints, dependent: :restrict_with_error

  normalizes :first_names, :last_names, :civil_status, :nationality, with: ->(value) { value.squish.presence }
  normalizes :dni, :rtn, with: FieldFormats::DIGITS
  normalizes :phone, with: FieldFormats::PHONE
  normalizes :email, with: FieldFormats::EMAIL

  validates :first_names, :last_names, presence: true, field_format: :person_name, length: { maximum: 100 }
  validates :dni, field_format: :dni, uniqueness: true, allow_nil: true
  validates :rtn, field_format: :rtn, uniqueness: true, allow_nil: true
  validates :phone, field_format: :phone
  validates :email, field_format: :email, length: { maximum: 254 }
  validates :civil_status, :nationality, field_format: :person_name, length: { maximum: 100 }
  validate :role_chosen, if: :roles_from_form
  validate :producer_removable, :hauler_removable

  scope :alphabetical, -> { order(:last_names, :first_names) }
  scope :search, ->(term) {
    pattern = "%#{sanitize_sql_like(term.strip)}%"
    where("first_names ILIKE :p OR last_names ILIKE :p OR dni ILIKE :p OR rtn ILIKE :p", p: pattern)
  }
  # What a searchable picker types (PickerSearchesController): every word
  # must be in the names (ignoring case and accents), or, with digits, in
  # the DNI or RTN. "Ana Zelaya — 0801…" (a picker label) finds Ana.
  scope :picker_search, ->(text) {
    words = text.to_s.tr("—", " ").split.first(6)
    words.reduce(all) do |scope, word|
      digits = word.delete("^0-9")
      clause = digits.length >= 3 && digits == word.delete("-") ? NAMES_OR_NUMBERS_MATCH : NAMES_MATCH
      scope.where(clause, name: "%#{sanitize_sql_like(fold(word))}%", digits: "%#{digits}%")
    end
  }
  scope :clients, -> { joins(:client) }
  scope :collaborators, -> { joins(:collaborator) }
  scope :producers, -> { joins(:producer) }
  scope :haulers, -> { joins(:hauler) }

  def full_name
    "#{first_names} #{last_names}"
  end

  alias_method :audit_label, :full_name

  # What is still empty, for the notices of the forms that pick the person
  # (a loan, a payroll; Fernando, 2026-10-18, like Producer#missing_fields).
  # Only a notice: none of them is required.
  def missing_fields
    fields = %i[dni rtn phone email zone_id].select { |field| public_send(field).blank? }.map { |field| self.class.human_attribute_name(field) }
    fields << I18n.t("addresses.title") if [ department_id, municipality_id, address_line ].any?(&:blank?)
    fields
  end

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

  def hauler?
    hauler.present?
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

  # A new hauler's commission percent and can price, from the form (both
  # required); an existing hauler edits them in its own form.
  %i[commission_percent can_price].each do |field|
    define_method(:"hauler_#{field}=") do |value|
      instance_variable_set(:"@hauler_#{field}", value.presence)
      hauler.public_send(:"#{field}=", value.presence) if hauler&.new_record?
    end
    define_method(:"hauler_#{field}") { hauler ? hauler.public_send(field) : instance_variable_get(:"@hauler_#{field}") }
  end

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
        public_send("build_#{role}", **role_defaults(role))
      elsif !wanted && current
        current.new_record? ? public_send("#{role}=", nil) : current.mark_for_destruction
      end
    end

    def role_defaults(role)
      case role
      when :producer then { kind: producer_kind }
      when :hauler then { commission_percent: @hauler_commission_percent, can_price: @hauler_can_price }
      else {}
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

    # A hauler with purchases or payments stays one (it can be deactivated).
    def hauler_removable
      return unless hauler&.marked_for_destruction? && hauler.in_use?

      errors.add(:base, :hauler_in_use)
    end
end
