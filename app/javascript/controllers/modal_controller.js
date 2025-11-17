import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.element.addEventListener("click", (e) => {
      if (e.target === this.element) {
        this.close()
      }
    })
    
    this.element.addEventListener("modal:open", () => this.open())
    this.element.addEventListener("modal:close", () => this.close())
  }

  open() {
    this.element.classList.remove("hidden")
    setTimeout(() => {
      this.element.classList.remove("opacity-0", "pointer-events-none")
      this.contentTarget.classList.remove("scale-95")
      this.contentTarget.classList.add("scale-100")
    }, 10)
  }

  close() {
    this.element.classList.add("opacity-0", "pointer-events-none")
    this.contentTarget.classList.remove("scale-100")
    this.contentTarget.classList.add("scale-95")
    setTimeout(() => {
      this.element.classList.add("hidden")
    }, 300)
  }
}
