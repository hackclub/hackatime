import { Controller } from "@hotwired/stimulus"

// Helper for debouncing
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

export default class extends Controller {
  static targets = ["searchInput", "searchResults", "searchLoading"]
  static values = { 
    searchUrl: String,
    addUrl: String
  }

  connect() {
    this._debouncedSearch = debounce(this.performSearch.bind(this), 300);
  }

  search() {
    const query = this.searchInputTarget.value.trim();
    if (query.length < 2) {
      this.searchResultsTarget.innerHTML = '';
      this.hideLoading();
      return;
    }
    this.showLoading();
    this._debouncedSearch(query);
  }

  async performSearch(query) {
    try {
      const response = await fetch(`${this.searchUrlValue}?query=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      });
      
      if (response.ok) {
        const users = await response.json();
        this.displayResults(users);
      } else {
        console.error('Search failed:', response.statusText);
        this.displayResults([]);
      }
    } catch (error) {
      console.error('Search error:', error);
      this.displayResults([]);
    } finally {
      this.hideLoading();
    }
  }

  displayResults(users) {
    if (users.length === 0) {
      this.searchResultsTarget.innerHTML = '<div class="friends-search-no-results">No users found</div>';
      return;
    }

    const resultsHTML = users.map(user => `
      <div class="friends-search-result" data-user-id="${user.id}">
        <div class="friends-search-result-avatar">
          <img src="${user.avatar_url}" alt="${user.display_name}" class="friends-search-result-img">
        </div>
        <div class="friends-search-result-info">
          <h4 class="friends-search-result-name">${user.display_name}</h4>
        </div>
        <button class="friends-search-result-add" 
                data-action="click->friend-search#addFriend" 
                data-user-id="${user.id}">
          Add Friend
        </button>
      </div>
    `).join('');

    this.searchResultsTarget.innerHTML = resultsHTML;
  }

  async addFriend(event) {
    const button = event.target;
    const userId = button.dataset.userId;
    
    button.disabled = true;
    button.textContent = 'Adding...';

    try {
      const response = await fetch(this.addUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ friend_id: userId })
      });

      const result = await response.json();

      if (response.ok) {
        button.textContent = 'Added!';
        button.classList.add('friends-search-result-added');
        // Update pending badge count
        this.updatePendingBadge();
        setTimeout(() => {
          // Remove the user from results
          button.closest('.friends-search-result').remove();
        }, 1000);
      } else {
        button.textContent = 'Error';
        console.error('Add friend failed:', result.error);
        setTimeout(() => {
          button.disabled = false;
          button.textContent = 'Add Friend';
        }, 2000);
      }
    } catch (error) {
      console.error('Add friend error:', error);
      button.textContent = 'Error';
      setTimeout(() => {
        button.disabled = false;
        button.textContent = 'Add Friend';
      }, 2000);
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

  showLoading() {
    if (this.hasSearchLoadingTarget) {
      this.searchLoadingTarget.style.display = 'flex';
    }
  }

  hideLoading() {
    if (this.hasSearchLoadingTarget) {
      this.searchLoadingTarget.style.display = 'none';
    }
  }
}
