# Fields for the filter bar of any list (see ListFilter and shared/_filters).
module FiltersHelper
  def filter_text_field(form, name, label, value:, placeholder: nil)
    filter_field(form, name, label) do
      form.search_field name, value:, maxlength: 100, placeholder:, class: "field-input"
    end
  end

  # An amount in lempiras (filtered as it is typed, like the search).
  def filter_number_field(form, name, label, value:, placeholder: nil)
    filter_field(form, name, label) do
      form.number_field name, value:, min: 0, step: 0.01, inputmode: "decimal", placeholder:, class: "field-input"
    end
  end

  def filter_date_field(form, name, label, value:)
    filter_field(form, name, label) { form.date_field name, value:, class: "field-input" }
  end

  # choices: [[label, value], ...]; the blank option means "no filter".
  def filter_select(form, name, label, choices, selected:, all: t("shared.filters.all"), **html_options)
    filter_field(form, name, label) do
      form.select name, options_for_select(choices, selected), { include_blank: all }, class: "field-input", **html_options
    end
  end

  # A checkbox that, when checked, sends name=1 (unchecked sends nothing).
  def filter_check_box(form, name, label, checked:)
    tag.div(class: "flex items-end") do
      tag.label(class: "flex min-h-11 cursor-pointer items-center gap-2 text-sm font-medium") do
        form.check_box(name, { checked:, include_hidden: false, class: "size-4 accent-primary" }, "1") + label
      end
    end
  end

  # Quick periods for a list filtered by from/to dates and season
  # (shared/_filter_status): [[label, values to set, active?], ...].
  # A filter without a season (the kardex) gets the date periods only.
  def quick_periods(filter, today: Time.zone.today)
    seasons = filter.respond_to?(:season_year)
    no_season = !seasons || filter.season_year.nil?
    ranges = { today: today..today, yesterday: today.yesterday..today.yesterday,
               this_week: today.beginning_of_week..today, this_month: today.beginning_of_month..today }
    periods = ranges.map do |key, range|
      [ t("shared.filters.quick.#{key}"), { from: range.begin.iso8601, to: range.end.iso8601, **(seasons ? { season_year: "" } : {}) },
        no_season && filter.from == range.begin && filter.to == range.end ]
    end
    return periods unless seasons

    season = Season.current.year
    periods << [ t("shared.filters.quick.this_season"), { from: "", to: "", season_year: season.to_s },
                 filter.season_year == season && filter.from.nil? && filter.to.nil? ]
    periods << [ t("shared.filters.quick.all"), { from: "", to: "", season_year: "" }, no_season && filter.from.nil? && filter.to.nil? ]
  end

  # The active filters as chips (shared/_filter_status): [[label, fields], ...].
  # The dates make one chip; the other fields need a label in `labels`:
  # field: ->(value) { "Zona: Sur" } (nil to leave it out).
  def filter_chips(filter, **labels)
    active = filter.active_fields
    chips = []
    chips << [ date_range_label(filter.from, filter.to), %i[from to] ] if active.intersect?(%i[from to])
    (active - %i[from to]).each do |name|
      # A label can be nil (a zone that no longer exists): no chip then.
      label = labels[name]&.call(filter.public_send(name))
      chips << [ label, [ name ] ] if label
    end
    chips
  end

  # Above a live list's results (shared/filter_status): how many there are
  # and a chip per active filter, with its × and «Limpiar todo». A search
  # box (q) is named by what was typed; any other field needs its label:
  # a lambda that gets the value, or the same [[label, value], ...] choices
  # as its list. #results must have run (ListFilter#total_count).
  def live_list_status(filter, periods: [], **labels)
    labels = labels.transform_values do |label|
      label.is_a?(Array) ? ->(value) { label.find { |_, option| option.to_s == value.to_s }&.first } : label
    end
    chips = filter_chips(filter, q: ->(text) { t("shared.filters.chips.q", text:) }, **labels)
    render "shared/filter_status", filter:, count: t("shared.filters.count", count: filter.total_count), chips:, periods:
  end

  def date_range_label(from, to)
    if from && to then from == to ? t("shared.filters.on_day", date: l(from)) : t("shared.filters.between", from: l(from), to: l(to))
    elsif from then t("shared.filters.since", date: l(from))
    elsif to then t("shared.filters.until", date: l(to))
    else t("shared.filters.any_date")
    end
  end

  private
    def filter_field(form, name, label, &field)
      tag.div do
        form.label(name, label, class: "field-label") + capture(&field)
      end
    end
end
