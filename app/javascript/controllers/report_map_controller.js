import { Controller } from "@hotwired/stimulus"
import "leaflet"

// A report's map (reports/reports/_map): a circle per person or farm, its
// area following the report's figure, so the biggest stand out. Hover shows
// the name and the figure; a tap opens its page when it has one.
export default class extends Controller {
  static values = { points: Array, tiles: String, attribution: String, labels: Object }

  connect() {
    const L = window.L
    this.map = L.map(this.element, { scrollWheelZoom: false, zoomControl: false })
    L.control.zoom({ zoomInTitle: this.labelsValue.zoom_in, zoomOutTitle: this.labelsValue.zoom_out }).addTo(this.map)
    // Leaflet names its popup's close button in English.
    this.map.on("popupopen", ({ popup }) => popup.getElement()?.querySelector(".leaflet-popup-close-button")?.setAttribute("aria-label", this.labelsValue.close))
    this.map.attributionControl.setPrefix(false)
    if (this.tilesValue) L.tileLayer(this.tilesValue, { maxZoom: 19, attribution: this.attributionValue }).addTo(this.map)

    const max = Math.max(...this.pointsValue.map((point) => Math.abs(point.value) || 0), 0)
    const circles = this.pointsValue.map((point) => {
      const radius = 6 + (max > 0 ? Math.sqrt(Math.abs(point.value) / max) * 22 : 0)
      const circle = L.circleMarker([ point.latitude, point.longitude ], {
        radius, color: "#6f4128", weight: 2, fillColor: "#a0673f", fillOpacity: 0.45
      })
      circle.bindTooltip(`<strong>${escape(point.label)}</strong><br>${escape(point.text)}`)
      if (point.url) circle.bindPopup(`<strong>${escape(point.label)}</strong><br>${escape(point.text)}<br><a href="${encodeURI(point.url)}" data-turbo-frame="_top">${escape(this.labelsValue.open)}</a>`)
      return circle.addTo(this.map)
    })

    this.bounds = L.featureGroup(circles).getBounds()
    this.fit()

    // Charts open folded or load hidden: redraw once the map has its size,
    // and frame the points the first time it has one.
    this.resize = new ResizeObserver(() => {
      this.map.invalidateSize()
      if (!this.fitted) this.fit()
    })
    this.resize.observe(this.element)
  }

  fit() {
    if (this.element.clientWidth === 0) return
    this.map.fitBounds(this.bounds, { padding: [ 30, 30 ], maxZoom: 13 })
    this.fitted = true
  }

  disconnect() {
    this.resize?.disconnect()
    this.map?.remove()
  }
}

function escape(text) {
  const span = document.createElement("span")
  span.textContent = text ?? ""
  return span.innerHTML
}
