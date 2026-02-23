// app/javascript/controllers/currency_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.inputTarget.addEventListener("input", this.format.bind(this))
    this.inputTarget.addEventListener("blur", this.format.bind(this))
    this.inputTarget.form?.addEventListener("submit", this.prepareForSubmit.bind(this))
    this.format()
  }

  format() {
    let raw = this.inputTarget.value.replace(/[^\d]/g, "")
    if (raw.length === 0) {
      this.inputTarget.value = ""
      return
    }
    let cents = parseInt(raw, 10)
    let dollars = (cents / 100).toFixed(2)
    // Add commas for thousands
    let parts = dollars.split('.')
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    this.inputTarget.value = parts.join('.')
  }

  prepareForSubmit() {
    let dollars = this.inputTarget.value.replace(/[^\d.]/g, "")
    let cents = Math.round(parseFloat(dollars) * 100)
    this.inputTarget.value = cents
  }
}
