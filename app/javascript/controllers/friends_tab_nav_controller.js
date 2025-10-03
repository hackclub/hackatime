import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Listen for turbo frame load events to update active tabs
    document.addEventListener('turbo:frame-load', this.handleFrameLoad.bind(this));
  }

  disconnect() {
    document.removeEventListener('turbo:frame-load', this.handleFrameLoad.bind(this));
  }

  updateActiveTab(event) {
    // Remove active class from all tabs
    const allTabs = this.element.querySelectorAll('.friends-tab');
    allTabs.forEach(tab => {
      tab.classList.remove('friends-tab-active');
    });
    
    // Add active class to clicked tab
    event.currentTarget.classList.add('friends-tab-active');
  }

  handleFrameLoad(event) {
    if (event.target.id === 'friends_content') {
      // Update pending badge after any frame load
      this.updatePendingBadge();
    }
  }

  updatePendingBadge() {
    fetch('/my/friends?tab=pending_count', {
      headers: { 'Accept': 'application/json' }
    })
    .then(response => response.json())
    .then(data => {
      const badge = document.getElementById('pending-badge');
      if (badge) {
        if (data.count > 0) {
          badge.textContent = `(${data.count})`;
          badge.style.display = 'inline';
        } else {
          badge.style.display = 'none';
        }
      }
    })
    .catch(error => console.log('Failed to load pending count:', error));
  }
}
