# Fields for the filter bar of any list (see ListFilter and shared/_filters).
module FiltersHelper
  def filter_text_field(form, name, label, value:, placeholder: nil)
    filter_field(form, name, label) do
      form.search_field name, value:, maxlength: 100, placeholder:, class: "field-input"
    end
  end

  def filter_date_field(form, name, label, value:)
    filter_field(form, name, label) { form.date_field name, value:, class: "field-input" }
  end

  # choices: [[label, value], ...]; the blank option means "no filter".
  def filter_select(form, name, label, choices, selected:, all: t("shared.filters.all"))
    filter_field(form, name, label) do
      form.select name, options_for_select(choices, selected), { include_blank: all }, class: "field-input"
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

  private
    def filter_field(form, name, label, &field)
      tag.div do
        form.label(name, label, class: "field-label") + capture(&field)
      end
    end
end
