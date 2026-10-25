# The search behind a searchable picker (record_picker_controller.js,
# PickerSearchesController). Lists that grow (producers, people) are not
# loaded with the form (Fernando, 2026-10-18): from MIN_LENGTH characters
# typed, the page asks for the first LIMIT matches, alphabetical.
class PickerSearch
  MIN_LENGTH = 3
  LIMIT = 20
  KINDS = %w[producers people collaborators].freeze

  def self.kind?(kind) = KINDS.include?(kind.to_s)

  # What one record carries to the page: its label, the details it misses
  # and, for a producer, its zone and its active farms (with theirs), which
  # the purchase form uses when it is picked.
  def self.data(record)
    case record
    when Producer
      { id: record.id, label: record.picker_label, zone_id: record.zone_id, missing: record.missing_fields,
        farms: record.farms.select(&:active?).sort_by(&:name).map { |farm| [ farm.id, farm.name, farm.missing_fields ] } }
    when Person
      { id: record.id, label: record.picker_label, missing: record.missing_fields, intermediary: record.intermediary? }
    end
  end

  attr_reader :kind, :text, :except

  # except: a person left out (the one being merged).
  def initialize(kind, text, except: nil)
    @kind = kind.to_s
    @text = text.to_s.squish
    @except = except.presence
  end

  def searchable? = text.length >= MIN_LENGTH

  # [records, whether there are more].
  def results
    return [ [], false ] unless searchable?

    records = scope.limit(LIMIT + 1).to_a
    [ records.first(LIMIT), records.size > LIMIT ]
  end

  def as_json(*)
    records, more = results
    { results: records.map { |record| self.class.data(record) }, more: }
  end

  private
    def scope
      case kind
      when "producers" then Producer.picker_search(text).includes(:person, :farms).alphabetical
      when "people" then people(Person.all)
      when "collaborators" then people(Person.collaborators)
      end
    end

    def people(scope)
      scope = scope.where.not(id: except) if except
      scope.picker_search(text).includes(:producer).alphabetical
    end
end
