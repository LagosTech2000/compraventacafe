import { Controller } from "@hotwired/stimulus"
import "chart.js"

// One chart of a report, from the config the server computed
// (Report#charts, ReportsHelper#report_chart_config):
//
//   { type, labels, datasets: [{ label, data, format, kind, axis }], options }
//
// type: bar, stacked, hbar, hstacked (horizontal and stacked), line, combo
// (bars + lines), pareto (bars + an accumulated % line), doughnut or scatter. format says how values read:
// money, quintals, pounds, percent, integer or number.
const PALETTE = ["#6f4128", "#c8873a", "#17774a", "#2f6690", "#8c5e9e", "#d1495b", "#4d908e", "#b08968", "#e9c46a", "#3a5a40", "#9c6644", "#7f8c8d"]

const number = new Intl.NumberFormat("es-HN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const whole = new Intl.NumberFormat("es-HN", { maximumFractionDigits: 0 })
const short = new Intl.NumberFormat("es-HN", { notation: "compact", maximumFractionDigits: 1 })

function format(value, kind, compact = false) {
  if (value === null || value === undefined) return "—"
  switch (kind) {
    case "money": return `L ${compact ? short.format(value) : number.format(value)}`
    case "percent": return `${compact ? whole.format(value) : number.format(value)} %`
    case "integer": return whole.format(value)
    default: return compact ? short.format(value) : number.format(value)
  }
}

export default class extends Controller {
  static values = { config: Object }

  connect() {
    const config = this.configValue
    const canvas = this.element.querySelector("canvas")
    const Chart = window.Chart
    if (!Chart || !canvas) return

    if (!config.labels.length && !config.datasets.some((set) => set.data.length)) {
      this.element.innerHTML = `<p class="grid h-full place-items-center text-sm text-ink-muted">${config.empty}</p>`
      return
    }

    const styles = getComputedStyle(document.documentElement)
    const ink = styles.getPropertyValue("--color-ink-muted").trim() || "#6e615a"
    const line = styles.getPropertyValue("--color-line").trim() || "#ebe2da"
    Chart.defaults.font.family = "Inter, ui-sans-serif, system-ui, sans-serif"
    Chart.defaults.color = ink

    this.chart = new Chart(canvas, this.build(config, line))
  }

  disconnect() {
    this.chart?.destroy()
  }

  build(config, gridColor) {
    const type = config.type
    const doughnut = type === "doughnut"
    const datasets = config.datasets.map((set, index) => this.dataset(set, index, type))
    const formats = Object.fromEntries(datasets.map((set) => [set.yAxisID || "y", set.format]))
    const scales = doughnut ? {} : this.scales(type, config, formats, gridColor)

    return {
      type: doughnut ? "doughnut" : type === "scatter" ? "scatter" : type === "line" ? "line" : "bar",
      data: { labels: config.labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: this.horizontal(type) ? "y" : "x",
        interaction: { mode: doughnut || type === "scatter" ? "nearest" : "index", intersect: doughnut || type === "scatter" },
        cutout: doughnut ? "62%" : undefined,
        scales,
        plugins: {
          legend: { display: doughnut || datasets.length > 1, position: doughnut && this.element.clientWidth > 420 ? "right" : "bottom", labels: { boxWidth: 12, usePointStyle: true } },
          tooltip: { callbacks: { label: (context) => this.tooltip(context, doughnut, type) } }
        }
      }
    }
  }

  dataset(set, index, type) {
    const line = type === "line" || set.kind === "line"
    const color = PALETTE[index % PALETTE.length]
    const base = { label: set.label, data: set.data, format: set.format, xFormat: set.x_format }

    if (type === "doughnut") {
      return { ...base, backgroundColor: set.data.map((_, i) => PALETTE[i % PALETTE.length]), borderColor: "#fffdfb", borderWidth: 2 }
    }
    if (type === "scatter") {
      return { ...base, backgroundColor: `${color}99`, borderColor: color, pointRadius: 4, pointHoverRadius: 6 }
    }
    if (line) {
      return { ...base, type: "line", borderColor: color, backgroundColor: color, borderWidth: 2, pointRadius: 2, tension: 0.3,
               spanGaps: true, yAxisID: set.axis === "y2" ? "y2" : "y", order: 0 }
    }
    return { ...base, backgroundColor: `${color}d9`, hoverBackgroundColor: color, borderRadius: 4, maxBarThickness: 48,
             yAxisID: set.axis === "y2" ? "y2" : "y", order: 1 }
  }

  scales(type, config, formats, gridColor) {
    const stacked = type === "stacked" || type === "hstacked"
    const valueAxis = (kind, extra = {}) => ({
      beginAtZero: type !== "scatter" && type !== "line", stacked, grid: { color: gridColor },
      ticks: { callback: (value) => format(value, kind, true) }, ...extra
    })
    const categoryAxis = { stacked, grid: { display: false }, ticks: { autoSkip: true, maxRotation: 0 } }

    if (this.horizontal(type)) return { x: valueAxis(formats.y), y: categoryAxis }
    if (type === "scatter") {
      const xFormat = config.datasets[0]?.x_format
      return { x: valueAxis(xFormat, { beginAtZero: false }), y: valueAxis(formats.y) }
    }

    const scales = { x: categoryAxis, y: valueAxis(formats.y) }
    if (formats.y2) {
      scales.y2 = valueAxis(formats.y2, { position: "right", grid: { drawOnChartArea: false } })
      if (type === "pareto") Object.assign(scales.y2, { min: 0, max: 100 })
    }
    return scales
  }

  horizontal(type) {
    return type === "hbar" || type === "hstacked"
  }

  tooltip(context, doughnut, type) {
    const set = context.dataset
    if (type === "scatter") {
      return `${set.label}: ${format(context.parsed.x, set.xFormat)} · ${format(context.parsed.y, set.format)}`
    }
    const value = doughnut ? context.parsed : (this.horizontal(type) ? context.parsed.x : context.parsed.y)
    const text = `${doughnut ? context.label : set.label}: ${format(value, set.format)}`
    if (!doughnut) return text

    const total = set.data.reduce((sum, item) => sum + (item || 0), 0)
    return total ? `${text} (${format((value / total) * 100, "percent")})` : text
  }
}
