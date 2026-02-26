import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    accountReferenceUrl: String,
    advisoriesUrl: String
  }

  connect() {
    this.referenceSnapshots = {}
    this.advisoriesFetchTimeout = null
    this.lastAdvisoriesReference = ""
  }

  refresh(event) {
    const detail = event?.detail
    if (!detail) {
      return
    }

    const transactionType = detail.transactionType
    const primaryReference = (detail.primaryReference ?? "").trim()
    const partyId = detail.partyId ?? detail.party_id
    const counterpartyReference = detail.counterpartyReference
    const cashReference = detail.cashReference
    const requestId = detail.requestId
    const cashAmountCents = detail.cashAmountCents ?? 0
    const cashImpactCents = detail.cashImpactCents ?? 0
    const projectedDrawerCents = detail.projectedDrawerCents ?? 0
    const readyToPost = detail.readyToPost
    const blockedReason = detail.blockedReason

    this.setText("summaryTransactionType", this.titleize(detail.transactionType || "N/A"))
    this.setText("primaryReferenceValue", primaryReference || "N/A")
    this.setText("counterpartyReferenceValue", counterpartyReference || "N/A")
    this.setText("cashReferenceValue", cashReference || "N/A")
    this.setText("summaryRequestId", requestId || this.currentRequestId() || "N/A")

    this.setHidden("counterpartyReferencePanel", transactionType !== "transfer")
    this.renderCashFlowSummary(transactionType, cashAmountCents || 0, cashImpactCents || 0, projectedDrawerCents || 0)
    this.renderReadiness(readyToPost, blockedReason)

    this.fetchAdvisoriesIfNeeded(primaryReference, partyId)
  }

  async populateReference(kind, reference) {
    if (!reference) {
      this.applyReferenceSnapshot(kind, {
        status: "N/A",
        ledger_balance_cents: 0,
        available_balance_cents: 0,
        last_posted_at: null,
        alerts: [],
        restrictions: []
      })
      return
    }

    try {
      const snapshot = await this.fetchReferenceSnapshot(reference)
      this.applyReferenceSnapshot(kind, snapshot)
    } catch (_error) {
      this.applyReferenceSnapshot(kind, {
        status: "Unavailable",
        ledger_balance_cents: 0,
        available_balance_cents: 0,
        last_posted_at: null,
        alerts: [],
        restrictions: []
      })
    }
  }

  applyReferenceSnapshot(kind, snapshot) {
    this.referenceSnapshots[kind] = {
      ledger_balance_cents: Number(snapshot.ledger_balance_cents || 0),
      available_balance_cents: Number(snapshot.available_balance_cents || 0),
      alerts: Array(snapshot.alerts),
      restrictions: Array(snapshot.restrictions)
    }
  }

  async fetchReferenceSnapshot(reference) {
    const url = new URL(this.accountReferenceUrlValue, window.location.origin)
    url.searchParams.set("reference", reference)

    const response = await fetch(url.toString(), {
      headers: { "Accept": "application/json" }
    })

    const body = await response.json()
    if (!response.ok || !body.ok) {
      throw new Error(body.error || "Reference lookup failed")
    }

    return body
  }

  renderReferenceInsights(transactionType) {
    const references = [
      ["Primary", this.referenceSnapshots.primary],
      ["Cash", this.referenceSnapshots.cash]
    ]

    if (transactionType === "transfer") {
      references.push(["Counterparty", this.referenceSnapshots.counterparty])
    }

    const alerts = references.flatMap(([label, snapshot]) =>
      Array(snapshot?.alerts).map((message) => `${label}: ${message}`)
    )

    const restrictions = references.flatMap(([label, snapshot]) =>
      Array(snapshot?.restrictions).map((message) => `${label}: ${message}`)
    )

    this.setHtml(
      "referenceAlerts",
      alerts.length > 0
        ? alerts.map((message) => `<div class="alert alert-warning text-sm"><span>${this.escapeHtml(message)}</span></div>`).join("")
        : '<p class="text-sm opacity-70">No active alerts.</p>'
    )

    this.setHtml(
      "referenceRestrictions",
      restrictions.length > 0
        ? restrictions.map((message) => `<div class="alert alert-info text-sm"><span>${this.escapeHtml(message)}</span></div>`).join("")
        : '<p class="text-sm opacity-70">No active restrictions.</p>'
    )
  }

  renderCashFlowSummary(transactionType, cashAmountCents, cashImpactCents, projectedDrawerCents) {
    const cashInCents = transactionType === "deposit" ? cashAmountCents : 0
    const cashOutCents = transactionType === "withdrawal" ? cashAmountCents : 0

    this.setText("summaryCashIn", this.formatCents(cashInCents))
    this.setText("summaryCashOut", this.formatCents(cashOutCents))
    this.setText("cashImpact", this.formatCents(cashImpactCents))
    this.setText("projectedDrawer", this.formatCents(projectedDrawerCents))
  }

  fetchAdvisoriesIfNeeded(primaryReference, partyId) {
    if (!this.hasAdvisoriesUrlValue) return
    if (!primaryReference && !partyId) {
      this.lastAdvisoriesReference = ""
      this.renderAdvisories([], null, "empty")
      return
    }

    const key = primaryReference || `party:${partyId}`
    if (key === this.lastAdvisoriesReference) return
    this.lastAdvisoriesReference = key

    if (this.advisoriesFetchTimeout) clearTimeout(this.advisoriesFetchTimeout)
    this.advisoriesFetchTimeout = setTimeout(() => {
      this.advisoriesFetchTimeout = null
      this.fetchAdvisories(primaryReference, partyId)
    }, 200)
  }

  async fetchAdvisories(primaryReference, partyId) {
    const url = new URL(this.advisoriesUrlValue, window.location.origin)
    if (partyId) {
      url.searchParams.set("party_id", partyId)
    } else if (primaryReference && !primaryReference.includes(":")) {
      url.searchParams.set("account_reference", primaryReference)
    } else {
      this.renderAdvisories([], null, "fetched")
      return
    }

    try {
      const response = await fetch(url.toString(), { headers: { Accept: "application/json" } })
      const body = await response.json()
      if (response.ok && body.ok) {
        const displayed = (body.advisories || []).filter((a) =>
          ["notice", "alert", "requires_acknowledgment", "restriction"].includes(a.severity)
        )
        this.renderAdvisories(displayed.slice(0, 5), body.record_path, "fetched")
      } else {
        this.renderAdvisories([], null, "fetched")
      }
    } catch {
      this.renderAdvisories([], null, "fetched")
    }
  }

  renderAdvisories(advisories, recordPath, state) {
    const placeholder = this.findPostingTarget("advisoriesPlaceholder")
    const list = this.findPostingTarget("advisoriesList")
    const viewAllLink = this.findPostingTarget("advisoriesViewAllLink")

    if (!placeholder || !list) return

    if (advisories.length === 0) {
      placeholder.hidden = false
      placeholder.textContent = state === "empty" ? "Select an account to view advisories." : "No advisories."
      list.hidden = true
      if (viewAllLink) viewAllLink.hidden = true
      return
    }

    placeholder.hidden = true
    list.hidden = false
    list.innerHTML = advisories
      .map((a) => {
        const cls = this.advisorySeverityClass(a.severity)
        return `<div class="${cls}"><span>${this.escapeHtml(a.title)}${a.body ? ": " + this.escapeHtml(a.body) : ""}</span></div>`
      })
      .join("")

    if (viewAllLink && recordPath) {
      viewAllLink.href = recordPath
      viewAllLink.hidden = false
    } else if (viewAllLink) {
      viewAllLink.hidden = true
    }
  }

  renderReadiness(readyToPost, blockedReason) {
    const badge = this.findPostingTarget("summaryReadinessBadge")
    this.setText("summaryReadinessBadge", readyToPost ? "Ready to Post" : "Blocked")
    this.setText("summaryReadinessReason", readyToPost ? "Balanced and required fields complete." : (blockedReason || "Resolve form issues before posting."))

    if (!badge) {
      return
    }

    badge.classList.add("badge")
    badge.classList.remove("badge-success", "badge-error", "badge-neutral")
    badge.classList.add(readyToPost ? "badge-success" : "badge-error")
  }

  currentRequestId() {
    const requestIdInput = this.findPostingTarget("requestId")
    return requestIdInput?.value || ""
  }

  titleize(value) {
    const normalized = String(value || "").trim()
    if (normalized.length === 0) {
      return "N/A"
    }

    return normalized.charAt(0).toUpperCase() + normalized.slice(1)
  }

  setText(postingTargetName, value) {
    const element = this.findPostingTarget(postingTargetName)
    if (element) {
      element.textContent = value
    }
  }

  setHtml(postingTargetName, value) {
    const element = this.findPostingTarget(postingTargetName)
    if (element) {
      element.innerHTML = value
    }
  }

  setHidden(postingTargetName, hidden) {
    const element = this.findPostingTarget(postingTargetName)
    if (element) {
      element.hidden = hidden
    }
  }

  findPostingTarget(targetName) {
    return this.element.querySelector(`[data-posting-form-target="${targetName}"]`)
  }

  formatCents(cents) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD"
    }).format((Number(cents) || 0) / 100)
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }

  advisorySeverityClass(severity) {
    switch (severity) {
      case "alert":
      case "requires_acknowledgment":
        return "alert alert-warning text-sm"
      case "restriction":
        return "alert alert-error text-sm"
      default:
        return "text-sm opacity-75"
    }
  }
}
