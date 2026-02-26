import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput",
    "resultsList",
    "partyIdInput",
    "clearButton"
  ]

  static values = {
    searchUrl: String,
    idDetailsUrlTemplate: String
  }

  connect() {
    this.searchTimeout = null
    this.selectedParty = null
    this.element.addEventListener("tx:form-reset", this.handleFormReset.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("tx:form-reset", this.handleFormReset.bind(this))
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
  }

  handleFormReset() {
    this.selectedParty = null
    this.hideResults()
    this.clearSelection()
  }

  search(event) {
    const q = this.searchInputTarget.value.trim()
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (q.length < 1) {
      this.hideResults()
      if (!this.selectedParty) {
        this.searchInputTarget.placeholder = "Search by name, phone, or city/state"
      }
      return
    }
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
      this.renderResults(Array.isArray(parties) ? parties : parties.parties || [])
    } catch {
      this.hideResults()
    }
  }

  renderResults(parties) {
    if (!this.hasResultsListTarget) return
    const list = this.resultsListTarget
    list.innerHTML = ""
    list.hidden = false
    if (parties.length === 0) {
      const empty = document.createElement("div")
      empty.className = "px-3 py-2 text-sm text-slate-500"
      empty.textContent = "No parties found"
      list.appendChild(empty)
      return
    }
    parties.forEach((p) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className = "block w-full text-left px-3 py-2 text-sm hover:bg-base-200 rounded"
      const parts = [ p.display_name || `Party #${p.id}` ]
      if (p.phone) parts.push(p.phone)
      if (p.city || p.state) parts.push([ p.city, p.state ].filter(Boolean).join(", "))
      item.textContent = parts.join(" · ")
      item.dataset.partyId = p.id
      item.dataset.partyName = p.display_name || `Party #${p.id}`
      item.addEventListener("click", () => this.selectParty(p))
      list.appendChild(item)
    })
  }

  async selectParty(party) {
    this.selectedParty = party
    const name = party.display_name || `Party #${party.id}`
    this.searchInputTarget.value = name
    this.searchInputTarget.readOnly = true
    this.hideResults()
    if (this.hasPartyIdInputTarget) {
      this.partyIdInputTarget.value = String(party.id)
    }
    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.hidden = false
    }
    if (this.hasIdDetailsUrlTemplateValue && this.idDetailsUrlTemplateValue) {
      try {
        const url = this.idDetailsUrlTemplateValue.replace("__ID__", String(party.id))
        const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
        if (response.ok) {
          const details = await response.json()
          this.element.dispatchEvent(new CustomEvent("party:id-details", { bubbles: true, detail: details }))
        } else {
          this.element.dispatchEvent(new CustomEvent("party:id-details", { bubbles: true, detail: {} }))
        }
      } catch {
        this.element.dispatchEvent(new CustomEvent("party:id-details", { bubbles: true, detail: {} }))
      }
    }
    this.dispatchRecalculate()
  }

  clearSelection() {
    this.selectedParty = null
    this.searchInputTarget.value = ""
    this.searchInputTarget.readOnly = false
    this.searchInputTarget.placeholder = "Search by name, phone, or city/state"
    if (this.hasPartyIdInputTarget) this.partyIdInputTarget.value = ""
    if (this.hasClearButtonTarget) this.clearButtonTarget.hidden = true
    this.element.dispatchEvent(new CustomEvent("party:id-details", { bubbles: true, detail: {} }))
    this.dispatchRecalculate()
  }

  onInput() {
    if (this.selectedParty) {
      this.clearSelection()
    }
    this.dispatchRecalculate()
  }

  hideResults() {
    if (this.hasResultsListTarget) this.resultsListTarget.hidden = true
  }

  dispatchRecalculate() {
    this.element.dispatchEvent(new CustomEvent("tx:changed", { bubbles: true }))
  }
}
