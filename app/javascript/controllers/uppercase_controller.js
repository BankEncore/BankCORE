import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  blur() {
    this.element.value = (this.element.value || "").toUpperCase()
  }
}
