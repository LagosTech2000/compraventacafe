# A number written out in words, for documents that state amounts in
# letters (the promissory note and the loan contract: "mil quinientos
# lempiras exactos"). The words come from es.yml (number_words); the rules
# are Spanish grammar: "un"/"veintiún" before a noun (lempiras, mil,
# millones), "cien" alone and "ciento" before more, "y" between tens and
# units from thirty on.
#
#   NumberWords.amount(1_521.5)  # => "mil quinientos veintiún lempiras con 50/100"
#   NumberWords.decimal(2.5)     # => "dos punto cinco"
module NumberWords
  module_function

  # The units shortened before a noun: "un", "veintiún".
  APOCOPE = { 1 => :one, 21 => :twenty_one }.freeze

  # Lempiras in words: "… lempiras exactos", or "… lempiras con 50/100".
  def amount(value)
    value = value.to_d.abs.round(2)
    whole = value.floor
    cents = ((value - whole) * 100).round.to_i
    words = integer(whole, apocope: true)
    return I18n.t("number_words.amount_exact", words:) if cents.zero?

    I18n.t("number_words.amount_with_cents", words:, cents: format("%02d", cents))
  end

  # A number that may have decimals, read digit group by group:
  # 2.5 => "dos punto cinco", 0.05 => "cero punto cero cinco".
  def decimal(value)
    whole, fraction = value.to_d.abs.to_s("F").split(".")
    fraction = fraction.to_s.sub(/0+\z/, "")
    words = integer(whole.to_i)
    return words if fraction.empty?

    zeros = fraction[/\A0*/].length
    [ words, word(:point), *Array.new(zeros) { units[0] }, (integer(fraction.to_i) if fraction.to_i.positive?) ].compact.join(" ")
  end

  # A whole number below a billion. apocope: true when a noun follows
  # ("un", "veintiún", "treinta y un").
  def integer(value, apocope: false)
    value = value.to_i
    return units[0] if value.zero?

    millions, rest = value.divmod(1_000_000)
    thousands, below = rest.divmod(1_000)
    parts = []
    if millions.positive?
      parts << (millions == 1 ? word(:one_million) : "#{below_thousand(millions, apocope: true)} #{word(:millions)}")
    end
    if thousands.positive?
      parts << (thousands == 1 ? word(:thousand) : "#{below_thousand(thousands, apocope: true)} #{word(:thousand)}")
    end
    parts << below_thousand(below, apocope:) if below.positive?
    parts.join(" ")
  end

  def below_thousand(value, apocope:)
    return word(:one_hundred) if value == 100

    hundreds, rest = value.divmod(100)
    [ (I18n.t("number_words.hundreds")[hundreds] if hundreds.positive?), (below_hundred(rest, apocope:) if rest.positive?) ].compact.join(" ")
  end

  def below_hundred(value, apocope:)
    return unit(value, apocope:) if value < units.size

    tens, rest = value.divmod(10)
    ten = I18n.t("number_words.tens")[tens]
    rest.zero? ? ten : "#{ten} #{word(:and)} #{unit(rest, apocope:)}"
  end

  def unit(value, apocope:)
    apocope && APOCOPE[value] ? I18n.t("number_words.apocope.#{APOCOPE[value]}") : units[value]
  end

  # 0 to 29: the ones written as a single word.
  def units = I18n.t("number_words.units")

  def word(key) = I18n.t("number_words.#{key}")
end
