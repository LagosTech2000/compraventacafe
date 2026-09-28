module TradingHelper
  def format_pounds(value)
    number_with_precision(value, precision: 2, delimiter: ",")
  end

  def format_money(value)
    number_to_currency(value)
  end

  # [[label, value], ...] for a closed list stored as strings.
  def enum_options(model_class, attribute, values)
    values.map { |value| [ model_class.human_attribute_name("#{attribute}/#{value}"), value ] }
  end

  def payment_status_badge(invoice)
    tag.span(invoice.human_payment_status, class: "badge #{invoice.paid? ? "badge-success" : "badge-danger"}")
  end
end
