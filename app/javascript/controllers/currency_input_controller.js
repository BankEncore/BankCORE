import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hiddenInput", "displayInput"]

  connect() {
    this.syncDisplayFromHidden()
    this.element.addEventListener("currency:set", this.handleSet.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("currency:set", this.handleSet.bind(this))
  }

  handleSet(event) {
    const cents = event.detail?.cents
    if (cents === undefined || cents === null) return
    const value = Math.max(0, parseInt(String(cents), 10) || 0)
    this.hiddenInputTarget.value = String(value)
    this.displayInputTarget.value = this.formatCents(value)
  }

  input(event) {
    const raw = event.target.value
    const cents = this.parseToCents(raw)
    this.hiddenInputTarget.value = String(cents)
    this.hiddenInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  blur() {
    const cents = parseInt(this.hiddenInputTarget.value, 10) || 0
    this.displayInputTarget.value = this.formatCents(cents)
  }

  syncDisplayFromHidden() {
    const raw = this.hiddenInputTarget.value
    const cents = parseInt(raw, 10)
    const value = Number.isNaN(cents) || cents < 0 ? 0 : cents
    this.hiddenInputTarget.value = String(value)
    this.displayInputTarget.value = this.formatCents(value)
  }

  parseToCents(str) {
    if (str === null || str === undefined) return 0
    const cleaned = String(str)
      .replace(/[$,]/g, "")
      .replace(/\s/g, "")
      .trim()
    if (cleaned === "") return 0
    const num = parseFloat(cleaned)
    if (Number.isNaN(num)) return 0
    const cents = Math.round(num * 100)
    return Math.max(0, cents)
  }

  formatCents(cents) {
    const value = Math.max(0, parseInt(cents, 10) || 0)
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD"
    }).format(value / 100)
  }
}
