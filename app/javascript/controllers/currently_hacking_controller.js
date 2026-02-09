import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "count", "content"]
  static values = { 
    interval: { type: Number, default: 60000 }, // 60 seconds
    countUrl: String,
    fullUrl: String
  }

  connect() {
    this.isExpanded = false
    this.isLoading = false
    this.isVisible = false
    this.startCountPolling()
    this.boundClickHandler = this.handleClick.bind(this)
    this.containerTarget.addEventListener('click', this.boundClickHandler)
  }

  disconnect() {
    this.stopCountPolling()
    this.containerTarget.removeEventListener('click', this.boundClickHandler)
  }

  handleClick(event) {
    const header = event.target.closest('.currently-hacking')
    if (header) {
      this.toggle()
    }
  }

  async toggle() {
    this.isExpanded = !this.isExpanded
    
    if (this.isExpanded) {
      this.showLoading()
      this.contentTarget.style.display = 'block'
      await this.gimmeAll()
    } else {
      this.contentTarget.style.display = 'none'
    }
  }

  showLoading() {
    this.contentTarget.innerHTML = `
      <div class="p-4 bg-dark">
        <div class="text-center text-muted text-md">Loading...</div>
      </div>
    `
  }

  showBanner() {
    if (!this.isVisible) {
      this.isVisible = true
      this.containerTarget.classList.remove('hidden')
      setTimeout(() => {
        this.containerTarget.classList.remove('-translate-y-full')
        this.containerTarget.classList.add('translate-y-0')
      }, 300)
    }
  }

  startCountPolling() {
    this.stopCountPolling()
    this.pollCount()
    this.countIntervalId = setInterval(() => {
      this.pollCount()
    }, this.intervalValue)
  }

  stopCountPolling() {
    if (this.countIntervalId) {
      clearInterval(this.countIntervalId)
      this.countIntervalId = null
    }
  }

  async pollCount() {
    try {
      const response = await fetch(this.countUrlValue, {
        headers: {
          "Accept": "application/json"
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.updateCount(data.count)
        this.showBanner()
      }
    } catch (e) {
      console.error(e)
    }
  }

  async gimmeAll() {
    if (this.isLoading) return
    
    this.isLoading = true
    try {
      const res = await fetch(this.fullUrlValue, {
        headers: {
          "Accept": "application/json"
        }
      })

      if (res.ok) {
        const data = await res.json()
        if (data.users) {
          this.r(data.users)
        }
      }
    } catch (error) {
      console.error("Failed to poll currently hacking:", error)
      this.contentTarget.innerHTML = `
        <div class="p-4 bg-dark">
          <div class="text-center text-muted text-sm">ruh ro, something broke :(</div>
        </div>
      `
    } finally {
      this.isLoading = false
    }
  }

  updateCount(count) {
    if (this.hasCountTarget) {
      const plural = count === 1 ? "person" : "people"
      this.countTarget.textContent = `${count} ${plural} currently hacking`
    }
  }

  r(u) {
    if (!u || u.length === 0) {
      this.contentTarget.innerHTML = `
        <div class="p-4 bg-dark">
          <div class="text-center text-muted text-sm italic">No one is currently hacking :(</div>
        </div>
      `
      return
    }

    const us = u.map(user => this.r1(user)).join('')
    
    this.contentTarget.innerHTML = `
      <div class="currently-hacking-list max-h-[60vh] max-w-[400px] overflow-y-auto p-1 bg-darker">
        <div class="space-y-1">
          ${us}
        </div>
      </div>
    `
  }

  r1(u) {
    const mention = this.r2(u)
    const project = u.active_project ? this.r3(u.active_project) : ''
    
    return `
      <div class="flex flex-col space-y-1 p-1">
        <div class="flex items-center">
          ${mention}
        </div>
        ${project}
      </div>
    `
  }

  r2(u) {
    const dis = u.display_name || `User ${u.id}`
    const url = u.avatar_url || ''
    
    const name = u.slack_uid ? 
      `<a href="https://hackclub.slack.com/team/${u.slack_uid}" target="_blank" class="text-blue-500 hover:underline">@${dis}</a>` :
      `<span class="text-white">${dis}</span>`
    
    return `
      <div class="user-info flex items-center gap-2">
        ${url ? `<img src="${url}" alt="${dis}'s avatar" class="w-6 h-6 rounded-full aspect-square" loading="lazy">` : ''}
        <span class="inline-flex items-center gap-1">
          ${name}
        </span>
      </div>
    `
  }

  r3(p) {
    const v = p.repo_url ? 
      p.repo_url.replace(/^https:\/\/github\.com\//, 'https://tkww0gcc0gkwwo4gc8kgs0sw.a.selfhosted.hackclub.com/') : ''
    
    const out = this.esc(p.name)
    
    return `
      <div class="text-sm italic text-muted ml-2">
        working on 
        ${p.repo_url ? `<a href="${p.repo_url}" target="_blank" class="text-accent hover:text-cyan-400 transition-colors">${out}</a>` : out}
        ${v ? `<a href="${v}" target="_blank" class="ml-1">🌌</a>` : ''}
      </div>
    `
  }
  
  esc(str) {
    if (str === null || str === undefined) return '';
    return str.toString().replace(/[&<>"']/g, function (match) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[match];
    });
  }
}
