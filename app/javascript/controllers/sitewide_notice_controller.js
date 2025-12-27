import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "banner"]

  connect() {
    // Banner in case we ever want to use it 
    // if (this.hasBannerTarget) {
    //   this.bannerTarget.classList.remove("hidden")
    // }

    // side-wide noti scooter use it if ya want
    // if (!this.modalDismissed()) {
    //   this.openModal()
    // }
  }

  openModal() {
    this.modalTarget.classList.remove("hidden")
    document.documentElement.classList.add("overflow-hidden")
  }

  dismissModal() {
    window.localStorage.setItem(this.modalKey(), "1")
    this.modalTarget.classList.add("hidden")
    document.documentElement.classList.remove("overflow-hidden")
  }

  // Banner dismissa;
  dismissBanner() {
    this.bannerTarget.classList.add("hidden")
  }

  modalDismissed() {
    return window.localStorage.getItem(this.modalKey()) === "1"
  }

  modalKey() {
    return "hackatime_sitewide_required_update_modal_v1"
  }
}
