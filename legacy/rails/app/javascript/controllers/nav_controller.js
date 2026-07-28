import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "overlay", "button"]

  toggle() {
    const isOpen = this.navTarget.classList.contains("open")
    
    this.navTarget.classList.toggle("open")
    this.overlayTarget.classList.toggle("open")
    document.body.classList.toggle("overflow-hidden")
    
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", !isOpen)
    }
  }

  close() {
    this.navTarget.classList.remove("open")
    this.overlayTarget.classList.remove("open")
    document.body.classList.remove("overflow-hidden")
        if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }

  clickLink(event) {
    // Close nav when clicking links on mobile
    if (window.innerWidth <= 1024) {
      this.close()
    }
  }

  resize() {
    // Close nav when window is resized to desktop
    if (window.innerWidth > 1024) {
      this.close()
    }
  }

  connect() {
    // Listen for window resize
    window.addEventListener('resize', this.resize.bind(this))
    document.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  disconnect() {
    window.removeEventListener('resize', this.resize.bind(this))
    document.removeEventListener('keydown', this.handleKeydown.bind(this))
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }
}
