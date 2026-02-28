import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "resultsList", "hiddenInput", "maskedIdDisplay"]

  static values = {
    searchUrl: String
  }

  connect() {
    this.searchTimeout = null
    this.blurHideTimeout = null
    this.element.addEventListener("tx:form-reset", this.handleFormReset.bind(this))
    this.boundApplyPartyFromEvent = this.applyPartyFromEvent.bind(this)
    document.addEventListener("apply-last-party", this.boundApplyPartyFromEvent)
    if (this.hasResultsListTarget) {
      this.resultsListTarget.addEventListener("mousedown", this.boundCancelBlurHide = () => this.cancelBlurHide())
    }
    this.notifyPrefilledParty()
  }

  notifyPrefilledParty() {
    if (!this.hasHiddenInputTarget || !this.hasSearchInputTarget) return
    const partyId = this.hiddenInputTarget.value?.trim()
    const partyName = this.searchInputTarget.value?.trim()
    if (partyId && partyName) {
      requestAnimationFrame(() => {
        document.dispatchEvent(
          new CustomEvent("party-search:party-selected", {
            bubbles: true,
            detail: { partyId, partyName }
          })
        )
      })
    }
  }

  disconnect() {
    this.element.removeEventListener("tx:form-reset", this.handleFormReset.bind(this))
    document.removeEventListener("apply-last-party", this.boundApplyPartyFromEvent)
    if (this.hasResultsListTarget && this.boundCancelBlurHide) {
      this.resultsListTarget.removeEventListener("mousedown", this.boundCancelBlurHide)
    }
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (this.blurHideTimeout) clearTimeout(this.blurHideTimeout)
  }

  handleFormReset() {
    this.hideResults()
    this.clearMaskedIdDisplay()
    this.dispatchPartyCleared()
    if (this.hasHiddenInputTarget) {
      this.hiddenInputTarget.value = ""
    }
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
    }
  }

  search(event) {
    const q = this.searchInputTarget.value.trim()
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (q.length < 1) {
      this.hideResults()
      this.clearSelection()
      return
    }
    if (this.hasHiddenInputTarget) this.hiddenInputTarget.value = ""
    this.searchTimeout = setTimeout(() => this.fetchSearch(q), 200)
  }

  async fetchSearch(q) {
    if (!this.hasSearchUrlValue) return
    try {
      const url = new URL(this.searchUrlValue, window.location.origin)
      url.searchParams.set("q", q)
      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) return
      const parties = await response.json()
      this.renderResults(parties)
    } catch {
      this.hideResults()
    }
  }

  renderResults(parties) {
    if (!this.hasResultsListTarget) return
    const list = this.resultsListTarget
    list.innerHTML = ""
    if (parties.length === 0) {
      const empty = document.createElement("div")
      empty.className = "px-3 py-2 text-sm text-slate-500"
      empty.textContent = "No parties found"
      list.appendChild(empty)
    } else {
      parties.forEach((p) => {
        const item = document.createElement("button")
        item.type = "button"
        item.className = "block w-full text-left px-3 py-2 text-sm hover:bg-base-200 rounded border-b border-base-200 last:border-b-0"
        item.dataset.partyId = p.id
        item.innerHTML = this.formatPartyResult(p)
        item.addEventListener("click", () => this.selectParty(p))
        list.appendChild(item)
      })
    }
    list.hidden = false
  }

  formatPartyResult(p) {
    const relationship = (p.relationship_kind || "").replace("_", " ")
    const parts = []

    parts.push(`<div class="font-medium">${this.escapeHtml(p.display_name)}</div>`)
    if (relationship) {
      parts.push(`<div class="text-xs text-slate-600">${this.escapeHtml(relationship)}</div>`)
    }
    if (p.address) {
      parts.push(`<div class="text-xs text-slate-600">${this.escapeHtml(p.address)}</div>`)
    }
    if (p.phone) {
      parts.push(`<div class="text-xs text-slate-600">${this.escapeHtml(p.phone)}</div>`)
    }

    return parts.join("")
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }

  applyPartyFromEvent(event) {
    const p = event?.detail
    if (!p || !p.id) return
    this.selectParty(p)
  }

  selectParty(p) {
    if (this.hasHiddenInputTarget) {
      this.hiddenInputTarget.value = String(p.id)
    }
    this.searchInputTarget.value = p.display_name || `Party #${p.id}`
    this.hideResults()

    this.updateMaskedIdDisplay(p)
    document.dispatchEvent(
      new CustomEvent("party-search:party-selected", {
        bubbles: true,
        detail: { partyId: String(p.id), partyName: p.display_name || `Party #${p.id}` }
      })
    )

    this.dispatchRecalculate()
  }

  clearSelection() {
    this.clearMaskedIdDisplay()
    this.dispatchPartyCleared()
    if (this.hasHiddenInputTarget) {
      this.hiddenInputTarget.value = ""
    }
    this.dispatchRecalculate()
  }

  updateMaskedIdDisplay(p) {
    if (!this.hasMaskedIdDisplayTarget) return
    const el = this.maskedIdDisplayTarget
    if (p.govt_id && p.govt_id.toString().trim().length > 0) {
      const masked = p.govt_id.length > 4 ? `****${p.govt_id.slice(-4)}` : "****"
      const typeLabel = this.titleizeGovtIdType(p.govt_id_type)
      el.textContent = `ID: ${typeLabel} ${masked}`
      el.hidden = false
    } else {
      el.textContent = ""
      el.hidden = true
    }
  }

  clearMaskedIdDisplay() {
    if (!this.hasMaskedIdDisplayTarget) return
    this.maskedIdDisplayTarget.textContent = ""
    this.maskedIdDisplayTarget.hidden = true
  }

  titleizeGovtIdType(type) {
    if (!type || typeof type !== "string") return "ID"
    return type
      .replace(/_/g, " ")
      .replace(/\b\w/g, (c) => c.toUpperCase())
  }

  dispatchPartyCleared() {
    document.dispatchEvent(new CustomEvent("party-search:party-cleared", { bubbles: true }))
  }

  hideResults() {
    if (this.hasResultsListTarget) this.resultsListTarget.hidden = true
  }

  hideResultsOnBlur() {
    this.blurHideTimeout = setTimeout(() => this.hideResults(), 150)
  }

  cancelBlurHide() {
    if (this.blurHideTimeout) {
      clearTimeout(this.blurHideTimeout)
      this.blurHideTimeout = null
    }
  }

  dispatchRecalculate() {
    this.element.dispatchEvent(new CustomEvent("tx:changed", { bubbles: true }))
  }
}
