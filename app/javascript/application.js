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
  const can = document.getElementById('cancel-logout');

  if (!modal || !can) return;
  modal.classList.remove('hidden');

  function logshow() {
    modal.classList.remove('pointer-events-none');
    modal.classList.remove('opacity-0');
    modal.querySelector('.bg-dark').classList.remove('scale-95');
    modal.querySelector('.bg-dark').classList.add('scale-100');
  }

  function logquit() {
    modal.classList.add('opacity-0');
    modal.querySelector('.bg-dark').classList.remove('scale-100');
    modal.querySelector('.bg-dark').classList.add('scale-95');
    setTimeout(() => {
      modal.classList.add('pointer-events-none');
    }, 300);
  }

  window.showLogout = logshow;

  can.addEventListener('click', logquit);

  modal.addEventListener('click', function(e) {
    if (e.target === modal) {
      logquit();
    }
  });

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && !modal.classList.contains('pointer-events-none')) {
      logquit();
    }
  });
}

function weirdclockthing() {
  const clock = document.getElementById('clock');
  const display = clock.querySelector('.clock-display');

  if (!clock || !display) return;

  function write(something) {
    display.innerHTML = '';
    Array.from(something).forEach((char) => {
      const span = document.createElement('span');
      span.textContent = char === ' ' ? '\u00A0' : char;
      if (char === ':') {
        span.classList.add('blink');
      }
      display.appendChild(span);
    });
  }

  write("HAC:KA:TIME");

  function updateClock() {
    const date = new Date();
    const time = `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}:${String(date.getSeconds()).padStart(2, '0')}`;
    write(` ${time} `);
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
    write("HAC:KA:TIME");
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
