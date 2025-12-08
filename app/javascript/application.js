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

function outta() {
  // we should figure out a better way of doing this rather than this shit ass way, but it works for now
  const modal = document.getElementById('logout-modal');
  if (!modal) return;

  window.showLogout = function() {
    modal.dispatchEvent(new CustomEvent('modal:open', { bubbles: true }));
  };
}

function weirdclockthing() {
  const clock = document.getElementById('clock');

  if (!clock) return;

  clock.innerHTML = '';

  function write(element, something) {
    element.innerHTML = '';
    Array.from(something).forEach((char) => {
      const span = document.createElement('span');
      span.textContent = char === ' ' ? '\u00A0' : char;
      if (char === ':') {
        span.classList.add('blink');
      }
      element.appendChild(span);
    });
  }

  const inner = document.createElement('div');
  inner.className = 'clock-display-inner';

  const front = document.createElement('div');
  front.className = 'clock-display-front';
  write(front, "HAC:KA:TIME");

  const back = document.createElement('div');
  back.className = 'clock-display-back';

  inner.appendChild(front);
  inner.appendChild(back);
  clock.appendChild(inner);

  function updateClock() {
    const date = new Date();
    const time = `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}:${String(date.getSeconds()).padStart(2, '0')}`;
    write(back, ` ${time} `);
  }

  let intervalId = null;
  clock.onmouseenter = function () {
    updateClock();
    if (!intervalId) {
      intervalId = setInterval(updateClock, 1000);
    }
  }

  clock.onmouseleave = function () {
    clearInterval(intervalId);
    intervalId = null;
  }
}

// Handle both initial page load and subsequent Turbo navigations
document.addEventListener('turbo:load', function() {
  setupCurrentlyHacking();
  outta();
  weirdclockthing();
});
document.addEventListener('turbo:render', function() {
  setupCurrentlyHacking();
  outta();
  weirdclockthing();
});
document.addEventListener('DOMContentLoaded', function() {
  setupCurrentlyHacking();
  outta();
  weirdclockthing();
});
