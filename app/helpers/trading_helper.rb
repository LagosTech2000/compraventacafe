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
    classes = invoice.paid? ? "bg-success-soft text-success" : "bg-danger-soft text-danger"
    tag.span(invoice.human_payment_status, class: "rounded-full px-2 py-0.5 text-xs font-medium #{classes}")
  end
end
