import { Controller } from "@hotwired/stimulus"

// Sorts a table that shows all its rows in the browser (TableSortHelper):
// each header with text becomes a button; up, down, then back to the order
// the table came in. Headers with a server sort (a link) and the actions
// column are left alone. A cell's data-sort-value wins over its text;
// otherwise dates (31/12/2026 13:45), numbers and money (L 1,234.50, 12.5 %)
// and then text, without minding case or accents. Empty cells go last.
// Rows that belong together are kept together: a row with
// data-sort-with-previous follows the one before it.
export default class extends Controller {
  connect() {
    this.body = this.element.tBodies[0]
    if (!this.body) return

    this.original = [...this.body.rows]
    this.headers = [...this.element.tHead?.rows[0]?.cells || []]
    this.headers.forEach((th, index) => {
      if (th.classList.contains("cell-actions") || th.querySelector("a, button, input") || th.textContent.trim() === "" || th.dataset.sort === "false") return

      const button = document.createElement("button")
      button.type = "button"
      button.className = "sort-link"
      button.innerHTML = `<span></span><span class="sort-arrow" aria-hidden="true">↕</span>`
      button.firstChild.textContent = th.textContent.trim()
      button.addEventListener("click", () => this.sort(th, this.columnIndex(index)))
      th.replaceChildren(button)
      th.setAttribute("aria-sort", "none")
    })
  }

  // The cell index of a header, counting colspans.
  columnIndex(headerIndex) {
    return this.headers.slice(0, headerIndex).reduce((sum, th) => sum + (th.colSpan || 1), 0)
  }

  sort(th, column) {
    const next = { none: "ascending", ascending: "descending", descending: "none" }[th.getAttribute("aria-sort") || "none"]
    this.headers.forEach((header) => {
      if (!header.hasAttribute("aria-sort")) return
      header.setAttribute("aria-sort", "none")
      header.querySelector(".sort-link")?.classList.remove("sort-link-active")
      const arrow = header.querySelector(".sort-arrow")
      if (arrow) arrow.textContent = "↕"
    })
    th.setAttribute("aria-sort", next)
    if (next !== "none") {
      th.querySelector(".sort-link").classList.add("sort-link-active")
      th.querySelector(".sort-arrow").textContent = next === "ascending" ? "▲" : "▼"
    }

    const groups = this.groups(this.original)
    if (next !== "none") {
      const direction = next === "ascending" ? 1 : -1
      const keyed = groups.map((rows, index) => ({ rows, index, key: sortKey(rows[0].cells[column]) }))
      keyed.sort((a, b) => {
        if (a.key === null || b.key === null) return (a.key === null) - (b.key === null) || a.index - b.index
        return compare(a.key, b.key) * direction || a.index - b.index
      })
      this.body.append(...keyed.flatMap((group) => group.rows))
    } else {
      this.body.append(...groups.flat())
    }
  }

  groups(rows) {
    return rows.reduce((groups, row) => {
      if (row.dataset.sortWithPrevious !== undefined && groups.length) groups[groups.length - 1].push(row)
      else groups.push([ row ])
      return groups
    }, [])
  }
}

const DATE = /^(\d{1,2})\/(\d{1,2})\/(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$/
const NUMBER = /^[^\d-]*(-?[\d,]*\.?\d+)\s*%?$/

function sortKey(cell) {
  if (!cell) return null
  const raw = (cell.dataset.sortValue ?? cell.textContent).trim().replace(/\s+/g, " ")
  if (raw === "" || raw === "—") return null

  const date = raw.match(DATE)
  if (date) {
    const [, day, month, year, hour = 0, minute = 0, second = 0] = date
    return new Date(year, month - 1, day, hour, minute, second).getTime()
  }
  const number = raw.match(NUMBER)
  if (number && /\d/.test(raw) && raw.replace(/[\d,.\s%-]|^L |^US\$ ?/g, "").length <= 3) return parseFloat(number[1].replace(/,/g, ""))
  return raw.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
}

function compare(a, b) {
  if (typeof a === "number" && typeof b === "number") return a - b
  return String(a).localeCompare(String(b), "es", { numeric: true })
}
