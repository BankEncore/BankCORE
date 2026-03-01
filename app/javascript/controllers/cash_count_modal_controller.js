import { Controller } from "@hotwired/stimulus"

/**
 * Modal wrapper for denomination entry. Opens on trigger click; Apply commits
 * total and lines to parent via denomination:change.
 */
export default class extends Controller {
  static targets = ["dialog", "denominationEntry"]

  open() {
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "open")
    }
  }

  close() {
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }

  apply() {
    const denom = this.denominationEntryController
    if (!denom) return

    denom.recalculate()
    this.close()
  }

  cancel() {
    this.close()
  }

  get denominationEntryController() {
    if (!this.hasDenominationEntryTarget) return null
    return this.application.getControllerForElementAndIdentifier(
      this.denominationEntryTarget,
      "denomination-entry"
    )
  }
}
