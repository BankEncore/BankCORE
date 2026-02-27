import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["partyKind", "individualFields", "organizationFields"]

  connect() {
    this.updateVisibility()
    this.partyKindTarget.addEventListener("change", () => this.updateVisibility())
  }

  updateVisibility() {
    const kind = this.partyKindTarget.value
    this.individualFieldsTarget.style.display = kind === "individual" ? "block" : "none"
    this.organizationFieldsTarget.style.display = kind === "organization" ? "block" : "none"
  }
}
