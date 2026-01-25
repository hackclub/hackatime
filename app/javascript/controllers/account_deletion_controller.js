import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  confirm(event) {
    event.preventDefault();
    const modal = document.getElementById("account-deletion-confirm-modal");
    if (modal) {
      modal.dispatchEvent(new CustomEvent("modal:open", { bubbles: true }));
    }
  }
}
