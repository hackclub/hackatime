import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    // Handle trailing slashes or query params safely
    if (!window.location.pathname.startsWith("/docs/editors/godot")) return

    const key = this.storageKey()
    const dismissed = window.localStorage.getItem(key)

    if (!dismissed) this.open()
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    document.documentElement.classList.add("overflow-hidden")
  }

  dismiss() {
    window.localStorage.setItem(this.storageKey(), "1")
    this.modalTarget.classList.add("hidden")
    document.documentElement.classList.remove("overflow-hidden")
  }

  storageKey() {
    // bump this if you ever need to force-show again
    return "hackatime_godot_wakatime_upgrade_warning_v1_dismissed"
  }
}
