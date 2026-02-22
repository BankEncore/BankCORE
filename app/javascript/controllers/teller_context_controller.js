import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["branch", "workstation"]
  static values = { workstationsByBranch: Object }

  connect() {
    this.pendingWorkstationId = null
    this.hydrateFromStorage()
    this.populateWorkstations(this.pendingWorkstationId || this.workstationTarget.value)
    this.boundPersist = this.persistToStorage.bind(this)
    this.element.addEventListener("submit", this.boundPersist)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.boundPersist)
  }

  hydrateFromStorage() {
    const rawContext = localStorage.getItem("teller_context")
    if (!rawContext) return

    const savedContext = JSON.parse(rawContext)

    if (savedContext.branch_id && !this.branchTarget.value) {
      this.branchTarget.value = savedContext.branch_id
    }

    this.pendingWorkstationId = savedContext.workstation_id || null
  }

  branchChanged() {
    this.populateWorkstations()
  }

  populateWorkstations(preferredWorkstationId = null) {
    const branchId = this.branchTarget.value
    const workstationOptions = this.workstationsByBranchValue?.[branchId] || []

    this.workstationTarget.innerHTML = ""
    const placeholder = document.createElement("option")
    placeholder.value = ""
    placeholder.textContent = "Select workstation"
    this.workstationTarget.appendChild(placeholder)

    workstationOptions.forEach((workstation) => {
      const option = document.createElement("option")
      option.value = workstation.id
      option.textContent = workstation.name
      this.workstationTarget.appendChild(option)
    })

    const candidateValue = preferredWorkstationId || this.workstationTarget.value
    const hasCandidate = workstationOptions.some((workstation) => workstation.id === candidateValue)

    this.workstationTarget.value = hasCandidate ? candidateValue : ""
    this.workstationTarget.disabled = !branchId || workstationOptions.length === 0
    this.pendingWorkstationId = null
  }

  persistToStorage() {
    localStorage.setItem(
      "teller_context",
      JSON.stringify({
        branch_id: this.branchTarget.value,
        workstation_id: this.workstationTarget.value
      })
    )
  }
}
