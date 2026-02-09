// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

function setupCurrentlyHacking() {
  const header = document.querySelector('.currently-hacking');
  // only if no existing event listener
  if (!header) { return }
  header.onclick = function () {
    const container = document.querySelector('.currently-hacking-container');
    if (container) {
      container.classList.toggle('visible');
    }
  }
}

function outta() {
  // we should figure out a better way of doing this rather than this shit ass way, but it works for now
  const modal = document.getElementById('logout-modal');
  if (!modal) return;

  window.showLogout = function () {
    modal.dispatchEvent(new CustomEvent('modal:open', { bubbles: true }));
  };
}

// Handle both initial page load and subsequent Turbo navigations
document.addEventListener('turbo:load', function () {
  setupCurrentlyHacking();
  outta();
});
document.addEventListener('turbo:render', function () {
  setupCurrentlyHacking();
  outta();
});
document.addEventListener('DOMContentLoaded', function () {
  setupCurrentlyHacking();
  outta();
});
