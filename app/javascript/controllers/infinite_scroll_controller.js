import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, page: Number, total: Number }

  connect() {
    this.loading = false
    this.observer = new IntersectionObserver(e => this.onIntersect(e), { rootMargin: "200px" })
    this.loadPage()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async onIntersect(e) {
    if (e[0].isIntersecting && !this.loading && this.hasMore()) {
      this.pageValue++
      await this.loadPage()
    }
  }

  async loadPage() {
    if (this.loading) return
    this.loading = true

    try {
      const l = this.element.querySelector(".animate-pulse")?.parentElement
      
      if (!this.hasMore()) {
        if (l) l.remove()
        return
      }

      const r = await fetch(`${this.urlValue}&page=${this.pageValue}`)
      if (!r.ok) {
        if (l) l.remove()
        return
      }
      
      const h = await r.text()
      if (l) l.remove()

      if (h.trim()) this.element.insertAdjacentHTML("beforeend", h)

      if (this.hasMore()) {
        this.element.insertAdjacentHTML("beforeend", this.skeleton())
        this.observer.observe(this.element.lastElementChild)
      }
    } finally {
      this.loading = false
    }
  }

  hasMore() {
    return (this.pageValue - 1) * 100 < this.totalValue
  }

  skeleton() {
    return `<div class="divide-y divide-gray-800">${Array(10).fill(`
      <div class="flex items-center p-2 animate-pulse">
        <div class="w-12 h-6 bg-darkless rounded shrink-0"></div>
        <div class="w-8 h-8 bg-darkless rounded-full mx-4"></div>
        <div class="flex-1"><div class="h-4 w-32 bg-darkless rounded"></div></div>
        <div class="h-4 w-16 bg-darkless rounded shrink-0"></div>
      </div>`).join("")}</div>`
  }
}
