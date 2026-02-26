import { Controller } from "@hotwired/stimulus"

// Formats phone as 000-000-0000 x0000 (extension optional)
export default class extends Controller {
  blur() {
    const input = this.element
    const digits = (input.value || "").replace(/\D/g, "")
    if (digits.length === 0) {
      input.value = ""
      return
    }
    if (digits.length <= 10) {
      const m = digits.match(/^(\d{0,3})(\d{0,3})(\d{0,4})$/)
      input.value = [ m[1], m[2], m[3] ].filter(Boolean).join("-")
    } else {
      const main = digits.slice(0, 10)
      const ext = digits.slice(10)
      input.value = main.replace(/(\d{3})(\d{3})(\d{4})/, "$1-$2-$3") + " x" + ext
    }
  }
}
