import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async rotateKey(event) {
    event.preventDefault()
    
    if (!confirm("Are you sure you want to rotate your API key? Your old key will be immediately invalidated and you'll need to update it in all your applications.")) {
      return
    }

    const button = event.currentTarget
    const og = button.textContent
    button.textContent = "Rotating..."
    button.disabled = true

    try {
      const r = await fetch("/my/settings/rotate_api_key", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        }
      })

      const d = await r.json()

      if (r.ok && d.token) {
        this.m(d.token)
      } else {
        alert("Failed to rotate API key: " + (d.error || "Unknown error"))
      }
    } catch (error) {
      console.error("Error rotating API key:", error)
      alert("Failed to rotate API key. Please try again.")
    } finally {
      button.textContent = og
      button.disabled = false
    }
  }

  m(token) {
    const c = `
      <div id="api-key-modal" class="fixed inset-0 flex items-center justify-center z-[9999]" style="background-color: rgba(0, 0, 0, 0.5);backdrop-filter: blur(4px);">
        <div class="bg-darker rounded-lg p-6 max-w-md w-full mx-4 border border-gray-600">
          <h3 class="text-xl font-bold text-white mb-4">🔑 New API Key Generated</h3>
          <div class="space-y-4">
            <div>
              <p class="text-sm text-gray-300 mb-3">
                We have gone ahead and invalidated your old API key, here is your new API key. Update your editor configuration with this new key.
              </p>
              <div class="bg-gray-800 border border-gray-600 rounded p-3">
                <code id="new-api-key" class="text-sm text-white break-all">${token}</code>
              </div>
            </div>
            <div class="flex gap-3 pt-2">
              <button type="button" id="copy-api-key" 
                      class="flex-1 bg-primary hover:bg-red text-white px-4 py-2 rounded-lg transition-colors">
                Copy Key
              </button>
              <button type="button" id="close-modal" 
                      class="flex-1 bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg transition-colors">
                Close
              </button>
            </div>
          </div>
        </div>
      </div>
    `
    
    document.body.insertAdjacentHTML("beforeend", c)
    
    document.getElementById("copy-api-key").addEventListener("click", () => {
      navigator.clipboard.writeText(token).then(() => {
        const button = document.getElementById("copy-api-key")
        const og = button.textContent
        button.textContent = "Copied!"
        setTimeout(() => {
          button.textContent = og
        }, 2000)
      })
    })
    
    document.getElementById("close-modal").addEventListener("click", this.closeModal)
    
    document.getElementById("api-key-modal").addEventListener("click", (event) => {
      if (event.target.id === "api-key-modal") {
        this.closeModal()
      }
    })
  }

  closeModal() {
    const modal = document.getElementById("api-key-modal")
    if (modal) {
      modal.remove()
    }
  }
}
