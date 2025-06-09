// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

function setupCurrentlyHacking() {
  const header = document.querySelector('.currently-hacking');
  // only if no existing event listener
  if (!header) { return }
  header.onclick = function() {
    const container = document.querySelector('.currently-hacking-container');
    if (container) {
      container.classList.toggle('visible');
    }
  }
}

// Handle both initial page load and subsequent Turbo navigations
document.addEventListener('turbo:load', setupCurrentlyHacking);
document.addEventListener('turbo:render', setupCurrentlyHacking);
document.addEventListener('DOMContentLoaded', setupCurrentlyHacking);
