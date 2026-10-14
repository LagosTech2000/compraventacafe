# Sortable table headers (Fernando, 2026-10-13: every column sorts).
#
# Lists that load page by page sort on the server, the whole filtered list
# (ListFilter#sorts): the header is a link that asks for ?sort=key&dir=,
# inside the list's Turbo Frame, without reloading the page. Tables that show
# all their rows sort in the browser (table_sort_controller.js on the table):
# their headers stay plain <th>.
#
#   sorting = { filter: @filter, frame: "zones-list" }  # (extra_params: { tab: "x" })
#   <%= sort_th Zone.human_attribute_name(:name), :name, sorting %>
module TableSortHelper
  ARROWS = { "asc" => "▲", "desc" => "▼" }.freeze

  # A clicked column goes up, then down, then back to the list's own order.
  def sort_th(label, key = nil, sorting = nil, **options)
    filter = sorting&.dig(:filter)
    return tag.th(label, **options) unless key && filter&.sortable?(key)

    current = filter.sort == key.to_s ? filter.dir : nil
    following = { nil => { sort: key, dir: "asc" }, "asc" => { sort: key, dir: "desc" } }.fetch(current, {})
    query = filter.to_params.except("sort", "dir").merge(sorting.fetch(:extra_params, {}).stringify_keys)
                  .merge(following.stringify_keys)
    data = { turbo_frame: sorting[:frame], turbo_action: ("advance" unless modal_request?) }.compact

    tag.th(**options, aria: { sort: { "asc" => "ascending", "desc" => "descending" }.fetch(current, "none") }) do
      link_to url_for(query), class: "sort-link #{"sort-link-active" if current}", data:,
                              title: t("shared.sort.#{following[:dir] || "clear"}", column: label) do
        safe_join([ tag.span(label), tag.span(ARROWS.fetch(current, "↕"), class: "sort-arrow", aria: { hidden: true }) ])
      end
    end
  end

  # The Turbo Frame around a list that sorts on the server: its headers,
  # next pages and filters answer inside it, without reloading the page; its
  # other links (open, edit) go to the whole page. In a modal the address
  # stays (it is not the modal's page).
  def list_frame(id, &)
    turbo_frame_tag(id, class: "query-frame block", target: "_top",
                        data: { turbo_action: ("advance" unless modal_request?), controller: "frame-scroll" }.compact, &)
  end

  # The id of a list's filter form (shared/_filters).
  def list_form_id(filter) = "#{filter.class.name&.underscore&.dasherize || "list-filter"}-form"

  # The table attribute that lets the browser sort it, when the server does not.
  def table_sort_data(sorting = nil)
    sorting ? {} : { controller: "table-sort" }
  end
end
