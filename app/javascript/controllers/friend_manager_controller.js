import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    removeUrl: String
  }

  async removeFriend(event) {
    const button = event.target;
    const friendId = button.dataset.friendId;
    const friendName = button.dataset.friendName;
    
    // Show confirmation dialogue
    const confirmed = confirm(`Are you sure you want to remove ${friendName} from your friends?`);
    
    if (!confirmed) {
      return;
    }

    // Disable button and show loading state
    const originalText = button.textContent;
    button.disabled = true;
    button.textContent = '⏳';

    try {
      const response = await fetch(this.removeUrlValue, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ friend_id: friendId })
      });

      const result = await response.json();

      if (response.ok) {
        // Remove the friend card from the UI with animation
        const friendCard = button.closest('.friends-user-card');
        friendCard.style.transition = 'all 0.3s ease';
        friendCard.style.opacity = '0';
        friendCard.style.transform = 'translateX(-100%)';
        
        setTimeout(() => {
          friendCard.remove();
          
          // Check if there are no more friends and show empty state
          const friendsList = friendCard.closest('.friends-list');
          if (friendsList && friendsList.children.length === 0) {
            this.showEmptyState(friendsList);
          }
        }, 300);
      } else {
        console.error('Remove friend failed:', result.error);
        alert(`Failed to remove friend: ${result.error}`);
        
        // Restore button state
        button.disabled = false;
        button.textContent = originalText;
      }
    } catch (error) {
      console.error('Remove friend error:', error);
      alert('An error occurred while removing the friend. Please try again.');
      
      // Restore button state
      button.disabled = false;
      button.textContent = originalText;
    }
  }

  showEmptyState(friendsList) {
    const emptyState = document.createElement('div');
    emptyState.className = 'friends-empty-state';
    emptyState.innerHTML = `
      <div class="friends-empty-icon">👋</div>
      <h3 class="friends-empty-title">No friends yet</h3>
      <p class="friends-empty-text">Add some friends to see them here!</p>
    `;
    
    const parentContainer = friendsList.parentElement;
    parentContainer.replaceChild(emptyState, friendsList);
  }
}
