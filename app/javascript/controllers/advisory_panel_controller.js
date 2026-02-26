import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "title", "body"]
  static values = { acknowledgeUrlTemplate: String }

  connect() {
    this.pendingPost = null
  }

  show(event) {
    const { advisory, formData, url, requestId } = event.detail || {}
    if (!advisory) return

    this.pendingPost = { advisory, formData, url, requestId }

    if (this.hasTitleTarget) {
      this.titleTarget.textContent = advisory.title || "Advisory"
    }
    if (this.hasBodyTarget) {
      this.bodyTarget.textContent = advisory.body || ""
    }

    if (this.hasPanelTarget) {
      if (typeof this.panelTarget.showModal === "function") {
        this.panelTarget.showModal()
      } else {
        this.panelTarget.setAttribute("open", "open")
      }
    }
  }

  hide() {
    if (this.hasPanelTarget) {
      if (typeof this.panelTarget.close === "function") {
        this.panelTarget.close()
      } else {
        this.panelTarget.removeAttribute("open")
      }
    }
    this.pendingPost = null
  }

  cancel() {
    this.hide()
    this.element.dispatchEvent(new CustomEvent("tx:advisory-cancelled", { bubbles: true }))
  }

  async acknowledge() {
    const { advisory } = this.pendingPost || {}
    if (!advisory?.id) {
      this.hide()
      return
    }

    const url = this.acknowledgeUrlTemplateValue?.replace("__ID__", String(advisory.id))
    if (!url) {
      this.hide()
      return
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        }
      })

      const body = await response.json()
      if (!response.ok || !body.ok) {
        this.element.dispatchEvent(new CustomEvent("tx:advisory-error", {
          bubbles: true,
          detail: { message: body.error || "Acknowledgment failed" }
        }))
        return
      }

      const { formData, url: postUrl, requestId } = this.pendingPost
      if (formData && postUrl) {
        formData.append("acknowledged_advisory_ids[]", String(advisory.id))
        this.element.dispatchEvent(new CustomEvent("tx:post-after-advisory", {
          bubbles: true,
          detail: { requestId, url: postUrl, formData }
        }))
      }

      this.hide()
      this.pendingPost = null
    } catch (error) {
      this.element.dispatchEvent(new CustomEvent("tx:advisory-error", {
        bubbles: true,
        detail: { message: error.message || "Acknowledgment failed" }
      }))
    }
  }
}
