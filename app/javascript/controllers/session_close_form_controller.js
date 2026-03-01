import { Controller } from "@hotwired/stimulus"

/**
 * Handles session close form: updates closing cash currency input when
 * denomination:change fires (from the cash count modal).
 */
export default class extends Controller {
  static targets = ["closingCashWrapper"]

  onDenominationChange(event) {
    const { totalCents = 0 } = event.detail || {}
    if (!this.hasClosingCashWrapperTarget) return

    this.closingCashWrapperTarget.dispatchEvent(
      new CustomEvent("currency:set", { bubbles: true, detail: { cents: String(totalCents) } })
    )
  }
}
