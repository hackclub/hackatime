import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "count"]
  static values = { 
    interval: { type: Number, default: 60000 }, // 60 seconds to match cron
    url: String
  }

  connect() {
    this.lastFullFetch = Date.now() // Initialize to now to prevent immediate refetch on click
    this.startPolling()
    // Listen for visibility changes
    this.boundToggleHandler = this.handleVisibilityToggle.bind(this)
    document.addEventListener('click', this.boundToggleHandler)
  }

  disconnect() {
    this.stopPolling()
    document.removeEventListener('click', this.boundToggleHandler)
  }

  handleVisibilityToggle(event) {
    const header = event.target.closest('.currently-hacking')
    if (header && this.containerTarget.contains(header)) {
      // Poll immediately when opening if we haven't fetched the list recently
      setTimeout(() => {
        if (this.isVisible()) {
          const now = Date.now()
          const timeSinceLastFetch = now - this.lastFullFetch
          // Only fetch if we haven't fetched in the last 30 seconds
          if (timeSinceLastFetch > 30000) {
            this.poll()
          }
        }
      }, 50) // Small delay to allow class toggle to complete
    }
  }

  isVisible() {
    return this.containerTarget.classList.contains('visible')
  }

  startPolling() {
    this.stopPolling() // Clear any existing interval
    this.poll() // Initial poll
    this.intervalId = setInterval(() => {
      this.poll()
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
      this.intervalId = null
    }
  }

  async poll() {
    try {
      const includeList = this.isVisible()
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set('include_list', includeList.toString())
      
      // Track when we request the full list, not just when we get it back
      if (includeList) {
        this.lastFullFetch = Date.now()
      }
      
      const response = await fetch(url, {
        headers: {
          "Accept": "application/json"
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.updateCount(data.count)
        if (data.html) {
          this.updateFrame(data.html)
        }
      }
    } catch (error) {
      console.error("Failed to poll currently hacking:", error)
    }
  }

  updateCount(count) {
    if (this.hasCountTarget) {
      const plural = count === 1 ? "person" : "people"
      this.countTarget.textContent = `${count} ${plural} currently hacking`
    }
  }

  updateFrame(html) {
    const frame = document.getElementById("currently_hacking")
    if (frame && html) {
      // Save scroll position before updating
      const scrollContainer = frame.querySelector(".currently-hacking-list")
      const scrollTop = scrollContainer ? scrollContainer.scrollTop : 0
      
      // Update content
      frame.innerHTML = html
      
      // Restore scroll position after a brief delay to allow DOM update
      if (scrollTop > 0) {
        requestAnimationFrame(() => {
          const newScrollContainer = frame.querySelector(".currently-hacking-list")
          if (newScrollContainer) {
            newScrollContainer.scrollTop = scrollTop
          }
        })
      }
    }
  }
}
