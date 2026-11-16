module Maintenance
  # sales:recalculate — the sales that do not match their shipments
  # (integrity:sales) work their weights, lines and total out again with
  # the shipments' scales now (Sale#recalculate_weights!), keeping their
  # price and shipments. Undone by putting back what each had.
  class SalesRecalculate < Task
    self.key = "sales:recalculate"
    self.tier = :fill
    self.area = :sales

    SALE_COLUMNS = %w[net_weight origin_net_weight total payment_status].freeze
    LINE_COLUMNS = %w[net_weight origin_net_weight amount].freeze

    def sections
      sales = Sales.out_of_step
      lines = sales.map { |sale| t(:line, number: sale.display_number, total: money(sale.total)) }
      [ section(t(:title), sales.any? ? "warn" : "ok", lines.presence || [ t(:none) ]) ]
    end

    def apply!
      changed = Sales.out_of_step.map do |sale|
        before = { "id" => sale.id, **sale.attributes.slice(*SALE_COLUMNS).transform_values { it.is_a?(BigDecimal) ? it.to_s : it },
                   "lines" => sale.lines.select(&:active?).map { |line| { "id" => line.id, **line.attributes.slice(*LINE_COLUMNS).transform_values { it&.to_s } } } }
        sale.recalculate_weights!
        before
      end
      { "sales" => changed }
    end

    def sections_after_apply(changes)
      [ section(t(:title), "ok", [ t(:done, count: changes["sales"].size) ]) ]
    end

    def self.revert!(changes)
      changes["sales"].count do |before|
        sale = ::Sale.find_by(id: before["id"])
        next false unless sale

        before["lines"].each do |values|
          line = sale.lines.find_by(id: values["id"])
          next unless line

          line.assign_attributes(values.except("id"))
          line.save!(validate: false) if line.changed?
        end
        sale.assign_attributes(before.slice(*SALE_COLUMNS))
        sale.save!(validate: false) if sale.changed?
        true
      end
    end
  end
end
