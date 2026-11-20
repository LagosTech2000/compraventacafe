# People already registered that look like the one being written
# (Fernando, 2026-11-18: 24 merges and 20 producers deleted so far): the
# same DNI, RTN or phone, or every word of the names. Only a notice: it
# never blocks (two people can share a name).
class PersonDuplicates
  LIMIT = 5

  Match = Data.define(:person, :reasons)

  def initialize(first_names: nil, last_names: nil, dni: nil, rtn: nil, phone: nil, except_id: nil)
    @first_names = first_names.to_s.squish
    @last_names = last_names.to_s.squish
    @dni = FieldFormats::DIGITS.call(dni.to_s).presence
    @rtn = FieldFormats::DIGITS.call(rtn.to_s).presence
    @phone = FieldFormats::PHONE.call(phone.to_s).presence
    @except_id = except_id.presence
  end

  def matches
    @matches ||= begin
      found = Hash.new { |hash, person| hash[person] = [] }
      { dni: @dni, rtn: @rtn, phone: @phone }.each do |field, value|
        next unless value && value.length >= 8

        scope.where(field => value).each { found[it] << field }
      end
      scope.search("#{@first_names} #{@last_names}").each { found[it] << :name } if names?
      found.first(LIMIT).map { |person, reasons| Match.new(person:, reasons:) }
    end
  end

  def any? = matches.any?

  private
    # Both names with a word of 2 letters or more: «A» finds everyone.
    def names? = [ @first_names, @last_names ].all? { |names| names.split.any? { it.length >= 2 } }

    def scope
      people = Person.includes(:zone).alphabetical.limit(LIMIT)
      @except_id ? people.where.not(id: @except_id) : people
    end
end
