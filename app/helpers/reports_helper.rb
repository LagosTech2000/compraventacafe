# Reports screen: report pickers, values by type, figures and charts.
module ReportsHelper
  NUMERIC_TYPES = %i[money pounds quintals number integer percent].freeze
  # Columns of priority 2 show from a medium width, 3 only on wide tables.
  PRIORITY_CLASSES = { 1 => "", 2 => "hidden @3xl:table-cell", 3 => "hidden @5xl:table-cell" }.freeze

  def report_path_for(report_class, params = {})
    reports_report_path(report_class.key, params)
  end

  # Reports the user may see, by module: [[module name, [[title, url]]]].
  def report_type_options(current)
    groups = allowed_reports.group_by { |report| report.module_keys.many? ? "global" : report.module_key }
    grouped = groups.map do |module_key, reports|
      [ module_key == "global" ? t("reports.show.global") : AppModule.human_name(module_key),
        reports.map { |report| [ report.title, report_path_for(report) ] } ]
    end
    grouped_options_for_select(grouped, report_path_for(current.class))
  end

  def report_preset_options
    presets = ReportPreset.all.select { |preset| allowed_reports.include?(preset.report_class) }
    grouped = presets.group_by(&:report_class).map do |report, list|
      [ report.title, list.map { |preset| [ preset.title, report_path_for(report, preset.params) ] } ]
    end
    grouped_options_for_select(grouped)
  end

  def saved_report_options(saved_reports)
    usable = saved_reports.select { |saved| allowed_reports.include?(saved.report_class) }
    grouped = usable.group_by(&:report_class).map do |report, list|
      [ report.title, list.map { |saved| [ saved.name, report_path_for(report, saved.params) ] } ]
    end
    grouped_options_for_select(grouped)
  end

  # Listed periods, then the last seasons, then "Personalizado".
  def report_period_options(selected)
    keys = ReportPeriod::KEYS - %w[custom]
    seasons = (0..4).map { |back| Season.current.year - back }
    options = keys.map { |key| [ t("reports.periods.#{key}"), key ] } +
              seasons.map { |year| [ t("reports.periods.season", season: Season.new(year).label), "season_#{year}" ] } +
              [ [ t("reports.periods.custom"), "custom" ] ]
    options_for_select(options, selected)
  end

  def report_group_options(report)
    report.groupings.map { |grouping| [ t("reports.groups.#{grouping.key}"), grouping.key ] }
  end

  # "1 de oct – 11 de oct de 2026"
  def format_report_period(period)
    return t("reports.periods.everything") if period.all?

    range = period.range
    from = range.begin ? l(range.begin, format: :long) : t("reports.periods.beginning")
    to = range.end ? l(range.end, format: :long) : t("reports.periods.today_open")
    from == to ? from : t("reports.periods.range", from:, to:)
  end

  # --- Cells ----------------------------------------------------------------

  def report_value(column, row) = column.value.call(row)

  def report_detail_path(report, row)
    instance_exec(row, &report.detail_route) if report.detail?
  end

  def report_cell(column, row)
    value = report_value(column, row)
    return tag.span("—", class: "text-ink-muted") if value.nil? || value == ""

    case column.type
    when :badge
      text, tone = value
      tag.span(text, class: "badge badge-#{tone}")
    when :group then tag.span(value, class: "font-medium")
    else format_report_value(value, column.type)
    end
  end

  def format_report_value(value, type)
    return "—" if value.nil?

    case type
    when :money then format_money(value)
    when :pounds then format_pounds(value)
    when :quintals then number_with_precision(value, precision: 2, delimiter: ",")
    when :percent then "#{number_with_precision(value, precision: 1, delimiter: ",")} %"
    when :integer then number_with_delimiter(value.to_i)
    when :number then number_with_precision(value, precision: 2, delimiter: ",", strip_insignificant_zeros: true)
    when :date then l(value.to_date)
    when :datetime then l(value)
    else value.to_s
    end
  end

  # Plain values for the CSV file: numbers without format, dates ISO.
  def report_csv_value(column, row)
    value = report_value(column, row)
    case column.type
    when :badge then value&.first
    when :date then value&.to_date&.iso8601
    when :datetime then value && l(value)
    when :money, :pounds, :quintals, :number, :percent then value&.to_d&.round(2)&.to_s("F")
    else value
    end
  end

  def report_cell_class(column)
    [ PRIORITY_CLASSES.fetch(column.priority, ""),
      NUMERIC_TYPES.include?(column.type) ? "whitespace-nowrap text-right tabular-nums" : nil,
      %i[date datetime].include?(column.type) ? "whitespace-nowrap" : nil ].compact_blank.join(" ")
  end

  # Header that sorts by its column: largest (or newest) first, then the
  # other way.
  def report_sort_link(report, column)
    label = report.column_label(column)
    return label unless column.sort

    current = report.sort_key == column.key.to_s
    direction = current && report.sort_direction == "desc" ? "asc" : "desc"
    arrow = current ? (report.sort_direction == "desc" ? " ↓" : " ↑") : ""
    link_to "#{label}#{arrow}", report_path_for(report.class, report.filter.to_params.merge("sort" => column.key.to_s, "dir" => direction)),
            class: "hover:text-ink #{"text-ink" if current}",
            data: { turbo_action: "replace" }
  end

  def report_sort_aria(report, column)
    return unless report.sort_key == column.key.to_s

    report.sort_direction == "desc" ? "descending" : "ascending"
  end

  # --- Figures --------------------------------------------------------------

  # "▲ 12.5 %" against the previous period, green or red when the report
  # says which way is good news.
  def report_kpi_change(kpi)
    change = kpi.change
    return if change.nil?

    up = change.positive?
    tone = if change.zero? || kpi.good.nil? then "text-ink-muted"
    elsif (up && kpi.good == :up) || (!up && kpi.good == :down) then "text-success"
    else "text-danger"
    end
    arrow = change.zero? ? "=" : (up ? "▲" : "▼")
    text = "#{arrow} #{number_with_precision(change.abs * 100, precision: 1, delimiter: ",")} %"
    tag.span(text, class: "text-xs font-semibold #{tone}", title: t("reports.show.previous_value", value: format_report_value(kpi.previous, kpi.type)))
  end

  # --- Charts ---------------------------------------------------------------

  def report_chart_config(report, chart)
    { type: chart.type, labels: chart.labels, datasets: chart.datasets,
      options: chart.options.except(:wide), empty: t("reports.charts.empty") }.to_json
  end

  def report_chart_title(report, chart) = t("reports.types.#{report.key}.charts.#{chart.key}.title")
  def report_chart_help(report, chart) = t("reports.types.#{report.key}.charts.#{chart.key}.help")

  # Shade of a heat map cell, from 0 (none) to 1 (the busiest).
  def heat_style(value, max)
    return "" unless value.to_i.positive? && max.positive?

    "background-color: rgb(111 65 40 / #{(0.12 + (value.to_f / max) * 0.88).round(2)})"
  end

  private
    def allowed_reports
      @allowed_reports ||= Report.catalog.select { |report| policy(report).show? }
    end
end
