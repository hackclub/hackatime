import { Controller } from "@hotwired/stimulus"
import { FetchRequest } from '@rails/request.js'

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
  static targets = ["searchInput", "searchResults", "selectedUsersContainer", "userIdsInput", "dateInput"]

  static values = {
    currentUserJson: Object, 
    initialSelectedUsersJson: Array, 
    searchUrl: String,
    leaderboardUsersUrl: String
  }

  connect() {
    this.selectedUsers = new Map(); // Stores selected users {id: userObject}
    this._debouncedSearchImpl = debounce(this.search.bind(this), 300);
    
    try {
      console.log("Initializing timeline user selector");
      
      // Parse the JSON if it's a string
      let adminUser = this.currentUserJsonValue;
      if (typeof adminUser === 'string') {
        adminUser = JSON.parse(adminUser);
        console.log("Parsed admin user:", adminUser);
      }
      
      if (adminUser && adminUser.id) {
        // Ensure ID is a number
        adminUser.id = parseInt(adminUser.id, 10);
        this.addUserToSelection(adminUser, true); // true = isPillForAdmin
      }
      
      // Parse the JSON if it's a string
      let initialUsers = this.initialSelectedUsersJsonValue;
      if (typeof initialUsers === 'string') {
        initialUsers = JSON.parse(initialUsers);
        console.log("Parsed initial users:", initialUsers);
      }
      
      // Make sure it's an array
      if (Array.isArray(initialUsers)) {
        initialUsers.forEach(user => {
          // Ensure ID is a number
          if (user && user.id) {
            user.id = parseInt(user.id, 10);
            if (!adminUser || user.id !== adminUser.id) { 
              this.addUserToSelection(user, false);
            }
          }
        });
      }
      
      this.updateHiddenInput();
      this.updateDateLinks();
    } catch (error) {
      console.error("Error initializing user selector:", error);
    }
  }

  async search() {
    const query = this.searchInputTarget.value;
    if (query.length < 2) {
      this.searchResultsTarget.innerHTML = "";
      this.searchResultsTarget.classList.remove('active');
      return;
    }

    const request = new FetchRequest('get', `${this.searchUrlValue}?query=${encodeURIComponent(query)}`, { responseKind: 'json' })
    const response = await request.perform()

    if (response.ok) {
      const users = await response.json;
      console.log(`Found ${users.length} users in search results`);
      this.renderSearchResults(users);
    } else {
      this.searchResultsTarget.innerHTML = "<li class='list-group-item list-group-item-light disabled'>Error searching users</li>";
      this.searchResultsTarget.classList.add('active');
    }
  }

  renderSearchResults(users) {
    if (users.length === 0) {
      this.searchResultsTarget.innerHTML = "<li class='list-group-item list-group-item-light disabled'>No users found</li>";
    } else {
      this.searchResultsTarget.innerHTML = users.map(user => `
        <li class="list-group-item list-group-item-action list-group-item-dark" 
            data-action="click->${this.identifier}#selectUser" 
            data-${this.identifier}-user-id-value="${user.id}" 
            data-${this.identifier}-user-display-name-value="${this.escapeHTML(user.display_name)}"
            data-${this.identifier}-user-avatar-url-value="${user.avatar_url || ''}">
          <img src="${user.avatar_url || 'https://via.placeholder.com/20'}" alt="${this.escapeHTML(user.display_name)}" class="avatar-xs me-2 rounded-circle">${this.escapeHTML(user.display_name)}
        </li>
      `).join("");
    }
    // Make sure the result list is shown
    this.searchResultsTarget.style.display = 'block';
    this.searchResultsTarget.classList.add('active');
    console.log("Search results rendered and active class added");
  }

  selectUser(event) {
    event.preventDefault();
    // Get values directly from data attributes
    const element = event.currentTarget;
    const userId = parseInt(element.getAttribute(`data-${this.identifier}-user-id-value`), 10);
    const displayName = element.getAttribute(`data-${this.identifier}-user-display-name-value`);
    const avatarUrl = element.getAttribute(`data-${this.identifier}-user-avatar-url-value`);
    
    console.log("Selected user data:", { userId, displayName, avatarUrl });
    
    if (isNaN(userId)) {
      console.error("Invalid user ID");
      this.clearSearch();
      return;
    }
    
    if (this.selectedUsers.has(userId)) {
      this.clearSearch();
      return;
    }

    const user = {
      id: userId,
      display_name: displayName,
      avatar_url: avatarUrl
    };
    
    this.addUserToSelection(user, false);
    
    this.clearSearch();
    this.updateHiddenInput();
    this.updateDateLinks();
  }

  addUserToSelection(user, isPillForAdmin = false) {
    // Make sure we have a valid user ID
    if (!user || !user.id || isNaN(parseInt(user.id, 10))) {
      console.error("Invalid user object or ID:", user);
      return;
    }
    
    // Convert ID to number just to be safe
    const userId = parseInt(user.id, 10);
    user.id = userId;
    
    if (this.selectedUsers.has(userId)) return;
    
    console.log("Adding user to selection:", user);
    this.selectedUsers.set(userId, user);
    
    const pill = document.createElement("span");
    // Using Pico.css friendly classes if available, or simple badges
    pill.classList.add("badge", "secondary", "me-1", "mb-1", "d-inline-flex", "align-items-center", "user-pill");
    pill.style.backgroundColor = isPillForAdmin ? 'var(--pico-primary-focus)' : 'var(--pico-muted-border-color)';
    pill.style.color = isPillForAdmin ? 'var(--pico-primary-inverse)' : 'var(--pico-color)';
    pill.style.padding = '0.3em 0.6em';
    pill.style.borderRadius = 'var(--pico-border-radius)';

    pill.dataset.userId = userId;
    
    let avatarImg = '';
    if (user.avatar_url) {
      avatarImg = `<img src="${user.avatar_url}" alt="${this.escapeHTML(user.display_name)}" class="avatar-xxs me-1 rounded-circle">`;
    }

    pill.innerHTML = `${avatarImg} ${this.escapeHTML(user.display_name)}`;

    if (!isPillForAdmin) {
      const removeButton = document.createElement("button");
      removeButton.type = "button";
      removeButton.classList.add("btn-close-custom", "ms-1"); // Custom class for styling
      removeButton.innerHTML = "&times;"; // Simple 'x'
      removeButton.dataset.action = `click->${this.identifier}#removeUser`;
      removeButton.setAttribute("aria-label", "Remove");
      pill.appendChild(removeButton);
    }
    
    this.selectedUsersContainerTarget.appendChild(pill);
  }
  
  removeUser(event) {
    const pill = event.target.closest(".user-pill");
    const userId = parseInt(pill.dataset.userId, 10);

    console.log("Removing user with ID:", userId);
    
    // Don't allow removing if it's the current user or an invalid ID
    if (isNaN(userId) || (this.currentUserJsonValue && userId === this.currentUserJsonValue.id)) return; 
    
    this.selectedUsers.delete(userId);
    pill.remove();
    this.updateHiddenInput();
    this.updateDateLinks();
  }

  async applyPreset(event) {
    event.preventDefault();
    const period = event.currentTarget.dataset.period;
    
    const request = new FetchRequest('get', `${this.leaderboardUsersUrlValue}?period=${period}`, { responseKind: 'json' })
    const response = await request.perform()

    if (response.ok) {
      const data = await response.json;
      const presetUsers = data.users;

      this.selectedUsersContainerTarget.querySelectorAll('.user-pill').forEach(pill => {
        const uid = parseInt(pill.dataset.userId);
        if (uid !== this.currentUserJsonValue.id) {
          pill.remove();
          this.selectedUsers.delete(uid);
        }
      });

      presetUsers.forEach(user => {
        if (user.id !== this.currentUserJsonValue.id) {
          this.addUserToSelection(user, false);
        }
      });

      this.updateHiddenInput();
      this.updateDateLinks();
    } else {
      console.error("Failed to load preset users");
      alert("Could not load preset users. Please try again.");
    }
  }

  updateHiddenInput() {
    this.userIdsInputTarget.value = Array.from(this.selectedUsers.keys()).join(',');
  }

  updateDateLinks() {
    const selectedIds = Array.from(this.selectedUsers.keys()).join(',');
    
    document.querySelectorAll('a[data-date-nav-link="true"]').forEach(link => {
      const url = new URL(link.href, window.location.origin);
      if (selectedIds) {
        url.searchParams.set('user_ids', selectedIds);
      } else {
        url.searchParams.delete('user_ids');
      }
      link.href = url.toString();
    });
  }
  
  submitForm() {
    const form = this.element.querySelector('form#timeline-filter-form');
    if (form) {
      if(this.hasDateInputTarget && form.elements.date) {
        form.elements.date.value = this.dateInputTarget.value;
      }
      form.requestSubmit();
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.clearSearch();
    }
  }
  
  clearSearch() {
    this.searchInputTarget.value = "";
    this.searchResultsTarget.innerHTML = "";
    this.searchResultsTarget.classList.remove('active');
    this.searchResultsTarget.style.display = 'none';
  }
  
  hideResultsDelayed() {
    setTimeout(() => {
      if (!this.searchResultsTarget.matches(':hover')) {
        this.clearSearch();
      }
    }, 200);
  }

  escapeHTML(str) {
    if (str === null || str === undefined) return '';
    return str.toString().replace(/[&<>"']/g, function (match) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[match];
    });
  }
  
  // This is just a wrapper to satisfy Stimulus data-action format
  // The actual debounced search implementation is stored in _debouncedSearchImpl
  debouncedSearch() {
    this._debouncedSearchImpl();
  }
} 