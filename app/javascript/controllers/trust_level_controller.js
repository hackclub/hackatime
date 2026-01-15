import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select"];

  connect() {
    this.selectTarget.addEventListener("change", this.handleChange.bind(this));
  }

  async handleChange(event) {
    const userId = event.target.dataset.userId;
    const trustLevel = event.target.value;

    if (!userId) {
      console.error("No user ID found in dataset");
      event.target.value = event.target.dataset.currentTrustLevel;
      alert("Error: No user ID found. Please try again.");
      return;
    }

    try {
      console.log("Updating trust level for user:", userId, "to:", trustLevel);
      const url = new URL(
        `/users/${userId}/update_trust_level`,
        window.location.origin
      );
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ trust_level: trustLevel }),
      });

      if (!response.ok) {
        throw new Error(
          `Failed to update trust level: ${response.status} ${response.statusText}`
        );
      }

      event.target.dataset.currentTrustLevel = trustLevel;
    } catch (error) {
      console.error("Error updating trust level:", error);
      // Revert the select to its previous value
      event.target.value = event.target.dataset.currentTrustLevel;
      alert("Failed to update trust level. Please try again.");
    }
  }
}
