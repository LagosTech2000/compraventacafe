import { Controller } from "@hotwired/stimulus"
import "leaflet"

// Where a person or a farm is (Fernando, 2026-10-13), on an OpenStreetMap
// map (Leaflet). In a form, a tap on the map puts the pin (it can be
// dragged), "Usar mi ubicación" puts it where the device is, and the
// latitude and longitude fields follow it, or move it when typed (e.g.
// pasted from Google Maps). With `readonly`, it only shows the pin.
export default class extends Controller {
  static targets = ["map", "latitude", "longitude", "clear", "status"]
  static values = { tiles: String, attribution: String, center: Array, readonly: Boolean, point: Array, locateFailed: String }

  connect() {
    const L = window.L
    this.map = L.map(this.mapTarget, { scrollWheelZoom: false, dragging: !this.readonlyValue || !L.Browser.mobile, zoomControl: true })
    this.map.attributionControl.setPrefix('<a href="https://leafletjs.com">Leaflet</a>')
    if (this.tilesValue) L.tileLayer(this.tilesValue, { maxZoom: 19, attribution: this.attributionValue }).addTo(this.map)
    if (!this.readonlyValue) this.map.on("click", (event) => this.place(event.latlng))

    const point = this.readonlyValue ? this.pointValue : this.typedPoint()
    if (point) {
      this.place(point, 15)
    } else {
      this.map.setView(this.centerValue, 7)
      this.toggleClear()
    }

    // In a modal or a drawer the map starts hidden or animating: redraw it
    // once it has its size.
    this.resize = new ResizeObserver(() => this.map.invalidateSize())
    this.resize.observe(this.mapTarget)
  }

  disconnect() {
    this.resize?.disconnect()
    this.map?.remove()
  }

  place(latlng, zoom) {
    const L = window.L
    const point = L.latLng(latlng)
    if (!this.marker) {
      const icon = L.divIcon({ className: "map-pin", html: "<span></span>", iconSize: [ 28, 28 ], iconAnchor: [ 14, 28 ] })
      this.marker = L.marker(point, { icon, draggable: !this.readonlyValue, keyboard: false }).addTo(this.map)
      this.marker.on("dragend", () => this.write(this.marker.getLatLng()))
    } else {
      this.marker.setLatLng(point)
    }
    zoom ? this.map.setView(point, zoom) : this.map.panTo(point)
    if (!this.readonlyValue) this.write(point)
  }

  write(point) {
    this.latitudeTarget.value = point.lat.toFixed(6)
    this.longitudeTarget.value = point.lng.toFixed(6)
    this.latitudeTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.toggleClear()
  }

  // Typed or pasted coordinates move the pin when both are valid.
  typed() {
    const point = this.typedPoint()
    if (point) this.place(point, Math.max(this.map.getZoom(), 15))
    this.toggleClear()
  }

  typedPoint() {
    const latitude = parseFloat(this.latitudeTarget.value)
    const longitude = parseFloat(this.longitudeTarget.value)
    const valid = Number.isFinite(latitude) && Number.isFinite(longitude) && Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180
    return valid ? [ latitude, longitude ] : null
  }

  locate() {
    this.statusTarget.hidden = true
    if (!navigator.geolocation) return this.say(this.locateFailedValue)

    navigator.geolocation.getCurrentPosition(
      (position) => this.place([ position.coords.latitude, position.coords.longitude ], 16),
      () => this.say(this.locateFailedValue),
      { enableHighAccuracy: true, timeout: 15000 }
    )
  }

  clear() {
    this.marker?.remove()
    this.marker = null
    this.latitudeTarget.value = ""
    this.longitudeTarget.value = ""
    this.toggleClear()
  }

  toggleClear() {
    if (this.hasClearTarget) this.clearTarget.hidden = !this.marker
  }

  say(message) {
    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
  }
}
