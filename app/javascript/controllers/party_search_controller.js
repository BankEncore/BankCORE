import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "resultsList", "hiddenInput"]

  static values = {
    searchUrl: String
  }

  connect() {
    this.searchTimeout = null
    this.element.addEventListener("tx:form-reset", this.handleFormReset.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("tx:form-reset", this.handleFormReset.bind(this))
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
  }

  handleFormReset() {
    this.hideResults()
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

  selectParty(p) {
    if (this.hasHiddenInputTarget) {
      this.hiddenInputTarget.value = String(p.id)
    }
    this.searchInputTarget.value = p.display_name || `Party #${p.id}`
    this.hideResults()

    document.dispatchEvent(
      new CustomEvent("party-search:govt-id-populate", {
        bubbles: true,
        detail: {
          govt_id_type: p.govt_id_type || "",
          govt_id: p.govt_id || ""
        }
      })
    )

    this.dispatchRecalculate()
  }

  clearSelection() {
    if (this.hasHiddenInputTarget) {
      this.hiddenInputTarget.value = ""
    }
    document.dispatchEvent(
      new CustomEvent("party-search:govt-id-populate", {
        bubbles: true,
        detail: { govt_id_type: "", govt_id: "" }
      })
    )
    this.dispatchRecalculate()
  }

  hideResults() {
    if (this.hasResultsListTarget) this.resultsListTarget.hidden = true
  }

  dispatchRecalculate() {
    this.element.dispatchEvent(new CustomEvent("tx:changed", { bubbles: true }))
  }
}
