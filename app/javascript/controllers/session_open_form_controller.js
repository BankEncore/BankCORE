import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    previousClosingUrl: String
  }

  static targets = ["openingWrapper", "openingInput", "openingDisplay", "priorBalanceDisplay"]

  fetchPreviousClosing(event) {
    const drawerId = event.target.value
    if (!this.previousClosingUrlValue) return

    if (!drawerId) {
      this.clearPriorBalance()
      return
    }

    const url = new URL(this.previousClosingUrlValue)
    url.searchParams.set("cash_location_id", drawerId)

    fetch(url.toString(), {
      headers: { "Accept": "application/json" }
    })
      .then((res) => res.json())
      .then((data) => {
        const cents = data.previous_closing_cents ?? 0
        this.showPriorBalance(cents)
        if (this.hasOpeningWrapperTarget) {
          this.openingWrapperTarget.dispatchEvent(
            new CustomEvent("currency:set", { bubbles: true, detail: { cents: String(cents) } })
          )
        }
      })
      .catch(() => this.clearPriorBalance())
  }

  showPriorBalance(cents) {
    if (!this.hasPriorBalanceDisplayTarget) return
    const formatted = this.formatCents(cents)
    const label = this.priorBalanceDisplayTarget.dataset.sessionOpenFormPriorLabel || "Previous closing: "
    this.priorBalanceDisplayTarget.textContent = label + formatted
  }

  clearPriorBalance() {
    if (!this.hasPriorBalanceDisplayTarget) return
    this.priorBalanceDisplayTarget.textContent = ""
  }

  formatCents(cents) {
    const value = Math.max(0, parseInt(cents, 10) || 0)
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD"
    }).format(value / 100)
  }
}
