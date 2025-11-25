import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  confirm(event) {
    event.preventDefault();
    document
      .getElementById("api-key-confirm-modal")
      .dispatchEvent(new CustomEvent("modal:open", { bubbles: true }));
  }

  async rotate(event) {
    event.preventDefault();

    const b = event.currentTarget;
    const og = b.textContent;
    b.textContent = "Rotating...";
    b.disabled = true;

    try {
      const r = await fetch("/my/settings/rotate_api_key", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        },
      });

      const data = await r.json();

      if (r.ok && data.token) {
        this.done(data.token);
      } else {
        alert("Failed to rotate API key: " + (data.error || "Unknown error"));
      }
    } catch (error) {
      console.error("Error rotating API key:", error);
      alert("Failed to rotate API key. Please try again.");
    } finally {
      b.textContent = og;
      b.disabled = false;
    }
  }

  done(token) {
    const d = document.getElementById("new-api-key-display");
    
    if (!d) {
      console.error("Could not find new-api-key-display element");
      alert("Error displaying new API key. Please refresh and try again.");
      return;
    }
    
    d.textContent = token;
    d.dataset.token = token;

    document
      .getElementById("api-key-confirm-modal")
      .dispatchEvent(new CustomEvent("modal:close", { bubbles: true }));
    
    setTimeout(() => {
      document
        .getElementById("api-key-success-modal")
        .dispatchEvent(new CustomEvent("modal:open", { bubbles: true }));
    }, 150);
  }

  copyKey(event) {
    event.preventDefault();
    const d = document.getElementById("new-api-key-display");

    if (!d) {
      console.error("modal issues???");
      return;
    }

    const t = d.dataset.token;
    const b = event.currentTarget;

    navigator.clipboard.writeText(t).then(() => {
      const og = b.textContent;
      b.textContent = "Copied!";
      setTimeout(() => {
        b.textContent = og;
      }, 2000);
    });
  }
}
