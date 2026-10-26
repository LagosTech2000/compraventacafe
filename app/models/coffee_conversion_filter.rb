# Processes (coffee conversions, Comercialización → Procesos): by status
# (voided ones only with "voided"), state they come from, where they were
# processed, the day they were weighed and their number.
class CoffeeConversionFilter < ListFilter
  field :from, :date
  field :to, :date
  field :status, :choice, in: CoffeeConversion::STATUSES
  field :from_state, :choice, in: CoffeeConversion::NEXT_STATE.keys
  field :q, :text
  field :processing_site_id, :id

  sorts number: "coffee_conversions.number", weighed_at: "coffee_conversions.weighed_at",
        from_state: "coffee_conversions.from_state",
        input_gross: "coffee_conversions.input_gross_weight", input_net: "coffee_conversions.input_net_weight",
        output_gross: "coffee_conversions.output_gross_weight", output_net: "coffee_conversions.output_net_weight",
        net_difference: "(coffee_conversions.output_net_weight - coffee_conversions.input_net_weight)",
        processing_site: { sql: text("processing_sites.name"), joins: :processing_site },
        yield: "(coffee_conversions.output_gross_weight / NULLIF(coffee_conversions.input_gross_weight, 0))",
        status: %w[coffee_conversions.voided_at coffee_conversions.finished_at]

  def apply(scope)
    scope = scope.where(weighed_at: from.in_time_zone.beginning_of_day..) if from
    scope = scope.where(weighed_at: ..to.in_time_zone.end_of_day) if to
    scope = status ? scope.with_status(status) : scope.active
    scope = scope.where(from_state:) if from_state
    scope = scope.where(processing_site_id:) if processing_site_id
    if q
      number = q.delete("^0-9").presence&.to_i
      scope = number ? scope.where(number:) : scope.where("coffee_conversions.observations ILIKE ?", like(q))
    end
    scope.includes(:created_by, :processing_site).newest_first
  end
end
