import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    acceptUrl: String,
    ignoreUrl: String,
    cancelUrl: String
  }

  async acceptRequest(event) {
    const button = event.target;
    const requesterId = button.dataset.requesterId;
    const requesterName = button.dataset.requesterName;
    
    await this.performAction(
      this.acceptUrlValue, 
      { requester_id: requesterId }, 
      button, 
      `Accepting ${requesterName}...`,
      () => {
        // Remove the card or update UI
        const card = button.closest('.friends-request-card');
        this.animateCardRemoval(card);
      }
    );
  }

  async ignoreRequest(event) {
    const button = event.target;
    const requesterId = button.dataset.requesterId;
    const requesterName = button.dataset.requesterName;
    const isUnignore = button.textContent.trim() === "Unignore";
    
    const confirmed = confirm(
      isUnignore 
        ? `Unignore friend request from ${requesterName}?`
        : `Ignore friend request from ${requesterName}?`
    );
    
    if (!confirmed) return;
    
    await this.performAction(
      this.ignoreUrlValue, 
      { requester_id: requesterId }, 
      button, 
      isUnignore ? 'Unignoring...' : 'Ignoring...',
      () => {
        // For now, reload the page to reflect changes
        window.location.reload();
      }
    );
  }

  async cancelRequest(event) {
    const button = event.target;
    const recipientId = button.dataset.recipientId;
    const recipientName = button.dataset.recipientName;
    
    const confirmed = confirm(`Cancel friend request to ${recipientName}?`);
    if (!confirmed) return;
    
    await this.performAction(
      this.cancelUrlValue, 
      { recipient_id: recipientId }, 
      button, 
      'Cancelling...',
      () => {
        const card = button.closest('.friends-request-card');
        this.animateCardRemoval(card);
      }
    );
  }

  async performAction(url, data, button, loadingText, onSuccess) {
    const originalText = button.textContent;
    button.disabled = true;
    button.textContent = loadingText;

    try {
      const response = await fetch(url, {
        method: url.includes('cancel') ? 'DELETE' : 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify(data)
      });

      const result = await response.json();

      if (response.ok) {
        onSuccess();
        // Update pending badge count
        this.updatePendingBadge();
      } else {
        console.error('Action failed:', result.error);
        alert(`Failed: ${result.error}`);
        button.disabled = false;
        button.textContent = originalText;
      }
    } catch (error) {
      console.error('Action error:', error);
      alert('An error occurred. Please try again.');
      button.disabled = false;
      button.textContent = originalText;
    }
  }

  animateCardRemoval(card) {
    card.style.transition = 'all 0.3s ease';
    card.style.opacity = '0';
    card.style.transform = 'translateX(-100%)';
    
    setTimeout(() => {
      card.remove();
      this.checkForEmptyState();
    }, 300);
  }

  checkForEmptyState() {
    // Check if sections are empty and show appropriate empty states
    const sections = this.element.querySelectorAll('.friends-pending-section');
    sections.forEach(section => {
      const friendsList = section.querySelector('.friends-list');
      if (friendsList && friendsList.children.length === 0) {
        this.showEmptyState(section, friendsList);
      }
    });
  }

  showEmptyState(section, friendsList) {
    const isIncoming = section.querySelector('h2').textContent.includes('Incoming');
    const emptyState = document.createElement('div');
    emptyState.className = 'friends-empty-state';
    emptyState.innerHTML = `
      <div class="friends-empty-icon">${isIncoming ? '📭' : '📤'}</div>
      <h3 class="friends-empty-title">No ${isIncoming ? 'incoming' : 'outgoing'} requests</h3>
      <p class="friends-empty-text">${isIncoming ? 'No one has sent you friend requests yet.' : "You haven't sent any friend requests."}</p>
    `;
    
    friendsList.parentElement.replaceChild(emptyState, friendsList);
  }

  toggleIgnoredIncoming(event) {
    this.navigateToTab('pending', {
      show_ignored_incoming: event.target.checked ? 'true' : null,
      show_unrequited_outgoing: this.getOtherCheckboxValue('show_unrequited_outgoing')
    });
  }

  toggleUnrequitedOutgoing(event) {
    this.navigateToTab('pending', {
      show_unrequited_outgoing: event.target.checked ? 'true' : null,
      show_ignored_incoming: this.getOtherCheckboxValue('show_ignored_incoming')
    });
  }

  navigateToTab(tab, params = {}) {
    const url = new URL('/my/friends', window.location.origin);
    url.searchParams.set('tab', tab);
    
    // Add non-null parameters
    Object.entries(params).forEach(([key, value]) => {
      if (value) {
        url.searchParams.set(key, value);
      }
    });

    // Find the turbo frame and navigate it
    const frame = document.getElementById('friends_content');
    if (frame) {
      frame.src = url.toString();
    }
  }

  getOtherCheckboxValue(checkboxName) {
    const checkbox = document.querySelector(`input[name="${checkboxName}"]`);
    return checkbox && checkbox.checked ? 'true' : null;
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
