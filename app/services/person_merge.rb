# Merges two people into one (Fernando, 2026-10-14): the same person
# registered twice, e.g. with the name written differently. The primary
# stays; for each detail where they differ the user picks whose value stays
# (field by field). Everything of the other one moves to the primary: its
# roles, and as a producer its purchases, invoices and farms (a farm with
# the same name as one of the primary's joins it: its purchases and
# payrolls go there and the copy is removed); its loans, its places in
# payrolls and its prints of private documents. Then the other person is
# deleted. All or nothing, recorded in the audit (action "merge"). It
# cannot be undone.
#
#   merge = PersonMerge.new(primary:, secondary:, choices: { "dni" => "secondary" })
#   merge.save   # => true, or false with merge.errors
#
# Two people in the same payroll cannot be merged: their days or cans in it
# would clash.
class PersonMerge
  include ActiveModel::Model

  SIDES = %w[primary secondary].freeze
  # Details chosen as a whole, and the attributes each one carries.
  PERSON_FIELDS = {
    "first_names" => %i[first_names], "last_names" => %i[last_names], "dni" => %i[dni], "rtn" => %i[rtn],
    "phone" => %i[phone], "email" => %i[email], "civil_status" => %i[civil_status], "nationality" => %i[nationality],
    "zone" => %i[zone_id],
    "address" => %i[department_id municipality_id address_line], "location" => %i[latitude longitude]
  }.freeze
  PRODUCER_FIELDS = { "kind" => %i[kind], "ihcafe_code" => %i[ihcafe_code] }.freeze
  # A farm that joins another fills what that one lacks, each group whole.
  FARM_GROUPS = [ %i[area_value area_unit], %i[department_id municipality_id address_line], %i[latitude longitude], %i[observations] ].freeze

  attr_reader :primary, :secondary, :choices, :moved

  def self.model_name = ActiveModel::Name.new(self, nil, "PersonMerge")

  def initialize(primary:, secondary:, choices: {})
    @primary = primary
    @secondary = secondary
    @choices = choices.to_h.transform_keys(&:to_s).select { |_, side| SIDES.include?(side) }
  end

  # --- What the screen compares ---------------------------------------------

  # The details where the two differ, each with the side chosen (by default
  # the primary's, unless only the other one has it).
  # Worked out once, before anything moves.
  def differences
    @differences ||= fields.select { |field| values(field, primary_record(field)) != values(field, secondary_record(field)) }
  end

  def fields
    list = PERSON_FIELDS.keys
    list += PRODUCER_FIELDS.keys if primary.producer && secondary.producer
    list << "photo" if primary.photo? || secondary.photo?
    list
  end

  def choice(field)
    return choices[field] if choices[field]

    primary_blank = blank?(field, primary_record(field))
    primary_blank && !blank?(field, secondary_record(field)) ? "secondary" : "primary"
  end

  # The record holding a detail on each side: the person, or its producer.
  def record(field, side)
    person = side == "primary" ? primary : secondary
    PRODUCER_FIELDS.key?(field) ? person.producer : person
  end

  def primary_record(field) = record(field, "primary")
  def secondary_record(field) = record(field, "secondary")

  # What moves from the other person, to say it before merging.
  def summary
    producer = secondary.producer
    prints = secondary.private_document_prints.count
    {
      purchases: producer ? producer.purchases.count : 0,
      invoices: producer ? producer.invoices.count : 0,
      farms: producer ? producer.farms.count : 0,
      loans: secondary.loans.count,
      payrolls: secondary.payroll_members.count,
      **({ hauled_purchases: secondary.hauler.purchases.count } if secondary.hauler),
      **({ document_prints: prints } if prints.positive?)
    }
  end

  # Farms of the other producer that join one of the primary's (same name).
  def joining_farms
    return [] unless primary.producer && secondary.producer

    names = primary.producer.farms.map { |farm| farm.name.downcase }
    secondary.producer.farms.select { |farm| names.include?(farm.name.downcase) }.map(&:name)
  end

  # Roles the primary gets from the other one.
  def gained_roles
    Person::ROLES.select { |role| secondary.public_send(:"#{role}?") && !primary.public_send(:"#{role}?") }
  end

  def shared_payrolls
    Payroll.where(id: primary.payroll_members.select(:payroll_id)).where(id: secondary.payroll_members.select(:payroll_id))
  end

  # --- Merging ------------------------------------------------------------------

  def valid?
    errors.clear
    errors.add(:base, :same_person) if primary == secondary
    if (payrolls = shared_payrolls.pluck(:name)).any?
      errors.add(:base, :shared_payroll, payrolls: payrolls.to_sentence)
    end
    errors.add(:base, :both_staff) if StaffMember.where(person_id: primary.id).exists? && StaffMember.where(person_id: secondary.id).exists?
    errors.empty?
  end

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      Person.where(id: [ primary.id, secondary.id ]).order(:id).lock.load
      @chosen = differences.select { |field| choice(field) == "secondary" }
      @moved = { roles: gained_roles.map(&:to_s), farms_joined: joining_farms }
      merge_producer
      merge_hauler
      Person::ROLES.excluding(:producer, :hauler).each { |role| merge_role(role) }
      @moved[:loans] = Loan.where(person_id: secondary.id).update_all(person_id: primary.id)
      @moved[:payrolls] = PayrollMember.where(person_id: secondary.id).update_all(person_id: primary.id)
      @moved[:staff] = StaffMember.where(person_id: secondary.id).update_all(person_id: primary.id)
      @moved[:document_prints] = PrivateDocumentPrint.where(person_id: secondary.id).update_all(person_id: primary.id)
      merge_photo
      merge_details
      label = "#{secondary.full_name} ##{secondary.id}"
      secondary.reload.destroy!
      record_audit(label)
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => error
    record = error.record
    errors.add(:base, :failed, detail: record.errors.full_messages.to_sentence.presence || record.class.model_name.human)
    false
  end

  private
    def values(field, record)
      return record&.photo? ? record.photo.id : nil if field == "photo"

      attributes = PERSON_FIELDS[field] || PRODUCER_FIELDS[field]
      attributes.map { |attribute| record&.public_send(attribute).presence }
    end

    def blank?(field, record)
      Array(values(field, record)).compact.empty?
    end

    def chosen_from_secondary(map)
      map.keys & @chosen
    end

    def merge_producer
      kept = primary.producer
      other = secondary.producer
      @moved[:purchases] = @moved[:invoices] = @moved[:farms] = 0
      return unless other

      unless kept
        other.update!(person: primary)
        return
      end

      producer_attributes = chosen_from_secondary(PRODUCER_FIELDS).flat_map { PRODUCER_FIELDS[it] }.index_with { other.public_send(it) }
      other.farms.each { |farm| move_farm(farm, kept) }
      @moved[:farms] = other.farms.size
      @moved[:purchases] = Purchase.where(producer_id: other.id).update_all(producer_id: kept.id)
      @moved[:invoices] = Invoice.where(producer_id: other.id).update_all(producer_id: kept.id)
      other.update_columns(ihcafe_code: nil) if producer_attributes.key?(:ihcafe_code)
      kept.update!(producer_attributes) if producer_attributes.any?
      Producer.find(other.id).destroy!
    end

    # A farm of the same name joins the kept one; any other changes owner.
    def move_farm(farm, kept)
      same = kept.farms.find_by("LOWER(name) = ?", farm.name.downcase)
      unless same
        farm.update_columns(producer_id: kept.id)
        return
      end

      Purchase.where(farm_id: farm.id).update_all(farm_id: same.id)
      Payroll.where(farm_id: farm.id).update_all(farm_id: same.id)
      fill = FARM_GROUPS.select { |group| group.all? { same.public_send(it).blank? } && group.any? { farm.public_send(it).present? } }
                        .flatten.index_with { farm.public_send(it) }
      same.update!(fill) if fill.any?
      Farm.find(farm.id).destroy!
    end

    # Carreros: both, the other's hauled purchases and payments go to the
    # primary's (who keeps their own percent and can price; each purchase
    # keeps the ones of its day). Only the other: it becomes the primary's.
    def merge_hauler
      kept = primary.hauler
      other = secondary.hauler
      return unless other

      if kept
        @moved[:hauled_purchases] = Purchase.where(hauler_id: other.id).update_all(hauler_id: kept.id)
        @moved[:hauler_payments] = HaulerPayment.where(hauler_id: other.id).update_all(hauler_id: kept.id)
        Hauler.find(other.id).destroy!
      else
        other.update!(person: primary)
      end
    end

    def merge_role(role)
      other = secondary.public_send(role)
      return unless other

      primary.public_send(role) ? other.destroy! : other.update!(person: primary)
    end

    def merge_photo
      return unless @chosen.include?("photo") && secondary.photo?

      primary.photo&.destroy!
      ProfilePhoto.where(owner: secondary).update_all(owner_id: primary.id)
      primary.reload
    end

    def merge_details
      attributes = chosen_from_secondary(PERSON_FIELDS).flat_map { PERSON_FIELDS[it] }.index_with { secondary.public_send(it) }
      return if attributes.empty?

      # The other one lets go of its unique numbers before the primary takes them.
      secondary.update_columns(attributes.slice(:dni, :rtn).transform_values { nil }) if attributes.key?(:dni) || attributes.key?(:rtn)
      primary.update!(attributes)
    end

    def record_audit(label)
      chosen = @chosen.map { |field| PersonMerge.field_name(field) }
      AuditEvent.record!(action: "merge", auditable: primary, label: primary.reload.full_name,
                         details: { "merged" => label,
                                    "moved" => moved.except(:roles, :farms_joined).map { |key, count| "#{I18n.t("administration.person_merges.moved.#{key}")}: #{count}" }.join(", "),
                                    "roles" => moved[:roles].map { |role| I18n.t("administration.person_merges.roles.#{role}") }.join(", ").presence,
                                    "farms_joined" => moved[:farms_joined].join(", ").presence,
                                    "chosen" => chosen.join(", ").presence }.compact)
    end

  public

  # The name of a detail on screen.
  def self.field_name(field)
    case field
    when "zone" then Person.human_attribute_name(:zone)
    when "address" then I18n.t("addresses.title")
    when "location" then I18n.t("administration.person_merges.fields.location")
    when "photo" then I18n.t("administration.person_merges.fields.photo")
    when *PRODUCER_FIELDS.keys then Producer.human_attribute_name(field)
    else Person.human_attribute_name(field)
    end
  end
end
