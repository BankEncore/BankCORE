import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["branch", "workstation"]

  connect() {
    this.hydrateFromStorage()
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

    if (savedContext.workstation_id && !this.workstationTarget.value) {
      this.workstationTarget.value = savedContext.workstation_id
    }
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
