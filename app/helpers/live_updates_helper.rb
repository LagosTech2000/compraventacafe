# A page that updates itself while open (LiveUpdates): it subscribes to the
# module streams it shows and refreshes by morphing, keeping the scroll.
# Shows "En vivo" at the bottom left while connected. Full pages only: a
# page in a modal leaves it to the page behind.
#
#   <%= live_updates_from :trading %>
module LiveUpdatesHelper
  def live_updates_from(*streams)
    return if modal_request?

    turbo_refreshes_with(method: :morph, scroll: :preserve)
    tag.div(class: "live-indicator print:hidden", data: { turbo_permanent: true }, id: "live-indicator-#{streams.join("-")}") do
      safe_join(streams.map { |stream| turbo_stream_from(stream) }) +
        tag.span(class: "live-badge", role: "status") do
          tag.span(class: "live-dot", aria: { hidden: true }) +
            tag.span(t("live_updates.on"), class: "live-on") +
            tag.span(t("live_updates.off"), class: "live-off")
        end
    end
  end
end
