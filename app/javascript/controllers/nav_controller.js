import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "overlay"]

  toggle() {
    this.navTarget.classList.toggle("open")
    this.overlayTarget.classList.toggle("open")
  }

  close() {
    this.navTarget.classList.remove("open")
    this.overlayTarget.classList.remove("open")
  }

  clickLink(event) {
    // Close nav when clicking links on mobile
    if (window.innerWidth <= 768) {
      this.close()
    }
  }

  resize() {
    // Close nav when window is resized to desktop
    if (window.innerWidth > 768) {
      this.close()
    }
  }

  connect() {
    // Listen for window resize
    window.addEventListener('resize', this.resize.bind(this))
  }

  disconnect() {
    window.removeEventListener('resize', this.resize.bind(this))
  }
}
