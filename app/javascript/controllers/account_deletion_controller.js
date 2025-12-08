import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    console.log("AccountDeletionController connected");
  }

  confirm(event) {
    event.preventDefault();
    console.log("AccountDeletionController#confirm called");
    const modal = document.getElementById("account-deletion-confirm-modal");
    if (modal) {
      modal.dispatchEvent(new CustomEvent("modal:open", { bubbles: true }));
    } else {
      console.error("Modal not found: account-deletion-confirm-modal");
    }
  }
}
