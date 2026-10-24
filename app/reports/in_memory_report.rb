# For reports whose rows come from several tables, few enough to put
# together in Ruby (CashMovementsReport, CoffeeStockReport): #load(period)
# returns the rows (each answering `date`, the sort keys and its measures),
# #apply_filters narrows them. This module sorts, groups, pages and exports
# them like the SQL reports do. A measure "count" counts rows; any other sums
# the row's method of the same name.
module InMemoryReport
  def records(in_period = period)
    @records ||= {}
    @records[in_period.range] ||= apply_filters(load(in_period))
  end

  def total_count = grouped? ? grouped_rows.size : records.size

  def page(number = filter.page)
    rows = grouped? ? grouped_rows : sorted_rows
    from = (number - 1) * Report::PER_PAGE
    [ rows[from, Report::PER_PAGE] || [], rows.size > from + Report::PER_PAGE ]
  end

  def each_row(&) = (grouped? ? grouped_rows : sorted_rows).first(Report::CSV_LIMIT).each(&)

  private
    def sorted_rows
      key = sort_key.to_sym
      present, missing = records.partition { |row| !row.public_send(key).nil? }
      present = present.sort_by { |row| [ row.public_send(key), row.date, row.id ] }
      present.reverse! if sort_direction == "desc"
      present + missing
    end

    def grouped_rows
      @grouped_rows ||= begin
        rows = records.group_by { |row| group_key(row) }.map do |key, list|
          values = measures.to_h do |measure|
            [ measure.key.to_s, measure.key == :count ? list.size : list.sum(0.to_d) { it.public_send(measure.key).to_d } ]
          end
          Report::GroupRow.new(key, group_label(key, nil), values)
        end
        rows = rows.sort_by { |row| sort_key == "group" ? row.key : row[sort_key] }
        sort_direction == "desc" ? rows.reverse : rows
      end
    end

    def group_key(row)
      grouping.unit ? bucket(row.date, grouping.unit) : row.public_send(grouping.key)
    end

    def bucket(date, unit)
      case unit
      when "week" then date.beginning_of_week
      when "month" then date.beginning_of_month
      else date
      end
    end

    def bucket_unit(_ = nil)
      dates = records.map(&:date)
      days = period.length_in_days || (dates.any? ? (dates.max - dates.min).to_i + 1 : 1)
      if days <= 45 then "day"
      elsif days <= 190 then "week"
      else "month"
      end
    end

    def sum_by(rows, amount, &label)
      rows.group_by(&label).map { |name, list| [ name, number(list.sum(0) { it.public_send(amount) }) ] }.sort_by { |_, value| -value }
    end
end
