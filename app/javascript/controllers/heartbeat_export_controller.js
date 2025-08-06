import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
// The Calender thing is mostly vibe coded, pls check

  handleExport(event) {
    event.preventDefault()
    
    this.showDateThing()
  }

  showDateThing() {
    const modalHTML = `
      <div id="export-modal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-darker rounded-lg p-6 max-w-md w-full mx-4 border border-gray-600">
          <h3 class="text-xl font-bold text-white mb-4">Export Heartbeats</h3>
          <form id="export-form">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-secondary mb-2">Start Date</label>
                <input type="date" id="start-date" 
                       class="w-full px-3 py-2 bg-darkless border border-gray-600 rounded-lg text-white focus:border-primary focus:outline-none"
                       value="${this.getDefaultStartDate()}">
              </div>
              <div>
                <label class="block text-sm font-medium text-secondary mb-2">End Date</label>
                <input type="date" id="end-date" 
                       class="w-full px-3 py-2 bg-darkless border border-gray-600 rounded-lg text-white focus:border-primary focus:outline-none"
                       value="${this.getDefaultEndDate()}">
              </div>
              <div class="flex gap-3 pt-4">
                <button type="button" id="cancel-export" 
                        class="flex-1 bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg font-semibold transition-colors">
                  Cancel
                </button>
                <button type="submit" id="confirm-export"
                        class="flex-1 bg-green hover:bg-green-600 text-white px-4 py-2 rounded-lg font-semibold transition-colors">
                  Export
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    `
    
    document.body.insertAdjacentHTML("beforeend", modalHTML)
    
    document.getElementById("cancel-export").addEventListener("click", this.closeme)
    document.getElementById("export-form").addEventListener("submit", this.exportIT.bind(this))
    
    document.getElementById("export-modal").addEventListener("click", (event) => {
      if (event.target.id === "export-modal") {
        this.closeme()
      }
    })
  }
  getDefaultStartDate() {
    const date = new Date()
    date.setDate(date.getDate() - 30)
    return date.toISOString().split("T")[0]
  }

  getDefaultEndDate() {
    return new Date().toISOString().split("T")[0]
  }

  closeme() {
    const modal = document.getElementById("export-modal")
    if (modal) {
      modal.remove()
    }
  }

  async exportIT(event) {
    event.preventDefault()
    
    const startDate = document.getElementById("start-date").value
    const endDate = document.getElementById("end-date").value
    
    if (!startDate || !endDate) {
      alert("Please select both start and end dates")
      return
    }
    
    if (new Date(startDate) > new Date(endDate)) {
      alert("Start date must be before end date")
      return
    }
    
    const submitButton = document.getElementById("confirm-export")
    const originalText = submitButton.textContent
    submitButton.textContent = "Exporting..."
    submitButton.disabled = true
    
    try {
      const exportUrl = `/my/heartbeats/export.json?start_date=${startDate}&end_date=${endDate}`
      
      const link = document.createElement("a")
      link.href = exportUrl
      link.download = `heartbeats_${startDate}_${endDate}.json`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      
      setTimeout(() => {
        this.closeme()
      }, 1000)
      
    } catch (error) {
      console.error("Export failed:", error)
      alert("Export failed. Please try again. :(")
      
      submitButton.textContent = originalText
      submitButton.disabled = false
    }
  }


}
