# The variables a private document (PrivateDocument) can carry and what
# each one says when it prints for a person, optionally with one of their
# loans. In the document's HTML a variable is
#
#   <span data-variable="person.full_name">[Nombre completo]</span>
#
# (the text inside is only its label, for the editor and the source view).
# A value the person or loan does not have prints as a blank line, to fill
# in by hand; so do the loan's variables when no loan is chosen.
#
#   variables = PrivateDocumentVariables.new(person:, loan:)
#   variables.value("loan.amount_in_words")  # => "mil quinientos lempiras exactos"
class PrivateDocumentVariables
  include ActionView::Helpers::NumberHelper

  # By group, in the order the editor lists them.
  GROUPS = {
    "person" => %w[full_name dni rtn address civil_status nationality phone zone],
    "loan" => %w[number amount amount_in_words cash_amount supplies_amount interest_rate interest_rate_in_words
                 kind disbursed_on due_on due_on_long due_day due_month due_year term],
    "today" => %w[date day month year],
    "business" => %w[name location rtn]
  }.freeze
  KEYS = GROUPS.flat_map { |group, names| names.map { |name| "#{group}.#{name}" } }.freeze
  # What an empty value prints: a line to write on.
  BLANK = "_" * 18

  def self.known?(key) = KEYS.include?(key)

  def self.label(key) = I18n.t("private_documents.variables.#{key}")

  def self.group_label(group) = I18n.t("private_documents.variable_groups.#{group}")

  attr_reader :person, :loan, :today

  def initialize(person:, loan: nil, today: Time.zone.today, site: SiteSetting.current)
    @person = person
    @loan = loan
    @today = today
    @site = site
  end

  # What the variable prints, or nil when there is nothing to put.
  def value(key)
    return unless self.class.known?(key)

    group, name = key.split(".", 2)
    case group
    when "person" then person_value(name)
    when "loan" then loan && loan_value(name)
    when "today" then date_value(today, name)
    when "business" then business_value(name)
    end.presence
  end

  private
    def person_value(name)
      case name
      when "full_name" then person.full_name
      when "dni" then grouped(person.dni, [ 4, 4, 5 ])
      when "rtn" then grouped(person.rtn, [ 4, 4, 6 ])
      when "address" then person.address_parts.join(", ")
      when "phone" then person.phone.to_s.match?(/\A\d{8}\z/) ? "#{person.phone[0, 4]}-#{person.phone[4, 4]}" : person.phone
      when "zone" then person.zone&.name
      else person.public_send(name)
      end
    end

    def loan_value(name)
      case name
      when "number" then loan.id.to_s
      when "amount" then money(loan.principal)
      when "amount_in_words" then NumberWords.amount(loan.principal)
      when "cash_amount" then money(loan.cash_amount)
      when "supplies_amount" then money(loan.supplies_amount)
      when "interest_rate" then number_with_precision(loan.monthly_interest_rate, precision: 2, strip_insignificant_zeros: true)
      when "interest_rate_in_words" then NumberWords.decimal(loan.monthly_interest_rate)
      when "kind" then loan.human_kind
      when "disbursed_on" then I18n.l(loan.disbursed_on)
      when "due_on" then I18n.l(loan.due_on)
      when "due_on_long" then I18n.l(loan.due_on, format: :long)
      when "due_day", "due_month", "due_year" then date_value(loan.due_on, name.delete_prefix("due_"))
      when "term" then I18n.t("private_documents.term_days", count: loan.term_days)
      end
    end

    def date_value(date, name)
      case name
      when "date" then I18n.l(date, format: :long)
      when "day" then date.day.to_s
      when "month" then I18n.t("date.month_names")[date.month]
      when "year" then date.year.to_s
      end
    end

    def business_value(name)
      case name
      when "name" then @site.business_name
      when "location" then @site.location
      when "rtn" then grouped(@site.rtn, [ 4, 4, 6 ])
      end
    end

    def money(amount) = number_with_precision(amount, precision: 2, delimiter: ",")

    # 0801199912345 => 0801-1999-12345
    def grouped(digits, sizes)
      return if digits.blank?
      return digits unless digits.length == sizes.sum

      offset = 0
      sizes.map { |size| digits[offset, size].tap { offset += size } }.join("-")
    end
end
