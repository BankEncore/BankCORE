import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "content", "unrecognizedMessage", "accountNumberContainer", "primaryOwner", "ledgerBalance", "pending", "projectedBalance"]
  static values = { accountReferenceUrl: String, accountPathTemplate: String }

  connect() {
    this.fetchTimeout = null
    this.lastReference = ""
  }

  refresh(event) {
    const detail = event?.detail
    if (!detail) return

    const primaryReference = (detail.primaryReference ?? "").trim()
    const entries = detail.entries ?? []

    if (!this.isAccountReference(primaryReference)) {
      this.hidePanel()
      return
    }

    const pendingCents = this.computePendingCents(primaryReference, entries)
    this.updatePendingAndProjected(pendingCents)

    if (primaryReference !== this.lastReference) {
      this.lastReference = primaryReference
      this.debouncedFetch(primaryReference)
    } else if (this.snapshot) {
      this.renderSnapshot(this.snapshot, pendingCents)
    }
  }

  isAccountReference(reference) {
    if (!reference || reference.length === 0) return false
    if (reference.includes(":")) return false
    return true
  }

  computePendingCents(primaryReference, entries) {
    if (!primaryReference || !Array.isArray(entries)) return 0
    return entries.reduce((sum, entry) => {
      if ((entry.account_reference ?? "").trim() !== primaryReference) return sum
      const amt = parseInt(entry.amount_cents ?? 0, 10)
      return entry.side === "credit" ? sum + amt : sum - amt
    }, 0)
  }

  debouncedFetch(reference) {
    if (this.fetchTimeout) clearTimeout(this.fetchTimeout)
    this.fetchTimeout = setTimeout(() => {
      this.fetchTimeout = null
      this.fetchSnapshot(reference)
    }, 300)
  }

  async fetchSnapshot(reference) {
    if (!this.accountReferenceUrlValue || !reference) return

    const url = new URL(this.accountReferenceUrlValue, window.location.origin)
    url.searchParams.set("reference", reference)

    try {
      const response = await fetch(url.toString(), { headers: { Accept: "application/json" } })
      const body = await response.json()
      if (response.ok && body.ok) {
        this.snapshot = body
        if (body.account_exists) {
          this.renderSnapshot(body, this.lastPendingCents ?? 0)
        } else {
          this.showUnrecognized()
        }
      } else {
        this.showUnrecognized()
      }
    } catch {
      this.showUnrecognized()
    }
  }

  updatePendingAndProjected(pendingCents) {
    this.lastPendingCents = pendingCents
    if (!this.hasPendingTarget) return
    this.pendingTarget.textContent = this.formatSignedCents(pendingCents)
    if (this.snapshot && this.hasProjectedBalanceTarget) {
      const ledger = parseInt(this.snapshot.ledger_balance_cents ?? 0, 10)
      const projected = ledger + pendingCents
      this.projectedBalanceTarget.textContent = this.formatCents(projected)
      this.projectedBalanceTarget.className = `ui-kv-value text-sm mono tabular-nums font-medium ${projected < 0 ? "text-error" : ""}`
    }
  }

  renderSnapshot(snapshot, pendingCents) {
    if (!this.hasPanelTarget) return

    const ledgerCents = parseInt(snapshot.ledger_balance_cents ?? 0, 10)
    const projectedCents = ledgerCents + pendingCents

    if (this.hasAccountNumberContainerTarget) {
      const accountNum = snapshot.reference ?? "—"
      const accountId = snapshot.account_id
      if (accountId && this.hasAccountPathTemplateValue) {
        const href = this.accountPathTemplateValue.replace("__ID__", String(accountId))
        this.accountNumberContainerTarget.innerHTML = `<a href="${this.escapeHtml(href)}" target="_blank" rel="noopener noreferrer" class="link link-hover">${this.escapeHtml(accountNum)}</a>`
      } else {
        this.accountNumberContainerTarget.textContent = accountNum
      }
    }
    if (this.hasPrimaryOwnerTarget) {
      this.primaryOwnerTarget.textContent = snapshot.primary_owner_name?.trim() || "—"
    }
    if (this.hasLedgerBalanceTarget) {
      this.ledgerBalanceTarget.textContent = this.formatCents(ledgerCents)
      this.ledgerBalanceTarget.className = `ui-kv-value text-sm mono tabular-nums ${ledgerCents < 0 ? "text-error font-medium" : ""}`
    }
    if (this.hasPendingTarget) {
      this.pendingTarget.textContent = this.formatSignedCents(pendingCents)
      this.pendingTarget.className = `ui-kv-value text-sm mono tabular-nums ${pendingCents !== 0 ? (pendingCents < 0 ? "text-error font-medium" : "ui-money") : ""}`
    }
    if (this.hasProjectedBalanceTarget) {
      this.projectedBalanceTarget.textContent = this.formatCents(projectedCents)
      this.projectedBalanceTarget.className = `ui-kv-value text-sm mono tabular-nums font-medium ${projectedCents < 0 ? "text-error" : ""}`
    }

    this.showContent()
    this.panelTarget.hidden = false
  }

  showUnrecognized() {
    if (!this.hasPanelTarget) return
    if (this.hasContentTarget) this.contentTarget.hidden = true
    if (this.hasUnrecognizedMessageTarget) this.unrecognizedMessageTarget.hidden = false
    this.panelTarget.hidden = false
  }

  showContent() {
    if (this.hasContentTarget) this.contentTarget.hidden = false
    if (this.hasUnrecognizedMessageTarget) this.unrecognizedMessageTarget.hidden = true
  }

  hidePanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.hidden = true
    }
    this.snapshot = null
    this.lastReference = ""
  }

  formatCents(cents) {
    const n = parseInt(cents, 10) || 0
    const sign = n < 0 ? "-" : ""
    return `${sign}$${Math.abs(n / 100).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  formatSignedCents(cents) {
    const n = parseInt(cents, 10) || 0
    const sign = n > 0 ? "+" : (n < 0 ? "-" : "")
    return `${sign}$${Math.abs(n / 100).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
