import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number, exitDuration: Number }

  connect() {
    const timeout = this.hasTimeoutValue ? this.timeoutValue : 6000
    this.exitDuration = this.hasExitDurationValue ? this.exitDurationValue : 250
    this.element.classList.add("flash-message--enter")
    this.hideTimeoutId = setTimeout(() => this.dismiss(), timeout)
  }

  disconnect() {
    if (this.hideTimeoutId) clearTimeout(this.hideTimeoutId)
    if (this.removeTimeoutId) clearTimeout(this.removeTimeoutId)
  }

  dismiss() {
    if (this.leaving) return
    this.leaving = true
    this.element.classList.add("flash-message--leaving")
    this.removeTimeoutId = setTimeout(() => {
      this.element.remove()
    }, this.exitDuration)
  }
}
