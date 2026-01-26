import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.modal = document.getElementById("export-date-range-modal")
    this.form = document.getElementById("export-date-range-form")
    this.form?.addEventListener("submit", this.handleExport.bind(this))
  }

  openModal(e) {
    e.preventDefault()
    const $ = id => document.getElementById(id)
    $("export-start-date").value = this.defaultDate(-30)
    $("export-end-date").value = this.defaultDate(0)
    this.modal?.dispatchEvent(new Event("modal:open", { bubbles: true }))
  }

  defaultDate(offset) {
    const d = new Date()
    d.setDate(d.getDate() + offset)
    return d.toISOString().split("T")[0]
  }

  handleExport(e) {
    e.preventDefault()
    const start = document.getElementById("export-start-date").value
    const end = document.getElementById("export-end-date").value

    if (!start || !end) return alert("Please select both start and end dates")
    if (new Date(start) > new Date(end)) return alert("Start date must be before end date")

    const a = document.createElement("a")
    a.href = `/my/heartbeats/export.json?start_date=${encodeURIComponent(start)}&end_date=${encodeURIComponent(end)}`
    a.download = `heartbeats_${encodeURIComponent(start)}_${encodeURIComponent(end)}.json`
    document.body.appendChild(a)
    a.click()
    a.remove()
    this.modal?.dispatchEvent(new Event("modal:close", { bubbles: true }))
  }
}
