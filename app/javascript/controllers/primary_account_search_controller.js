import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput",
    "resultsList",
    "partyAccountsRow",
    "partyName",
    "accountSelect"
  ]

  static values = {
    searchUrl: String,
    partyAccountsUrlTemplate: String,
    accountReferenceUrl: String
  }

  connect() {
    this.searchTimeout = null
    this.selectedPartyId = null
    this.partyAccounts = []
    this.isSelectingParty = false
    this.element.addEventListener("tx:form-reset", this.handleFormReset.bind(this))
    this.boundOnNowServingPartySelected = this.onNowServingPartySelected.bind(this)
    this.boundOnNowServingPartyCleared = this.onNowServingPartyCleared.bind(this)
    document.addEventListener("party-search:party-selected", this.boundOnNowServingPartySelected)
    document.addEventListener("party-search:party-cleared", this.boundOnNowServingPartyCleared)
  }

  disconnect() {
    this.element.removeEventListener("tx:form-reset", this.handleFormReset.bind(this))
    document.removeEventListener("party-search:party-selected", this.boundOnNowServingPartySelected)
    document.removeEventListener("party-search:party-cleared", this.boundOnNowServingPartyCleared)
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
  }

  onNowServingPartySelected(event) {
    const { partyId, partyName } = event.detail || {}
    if (partyId && this.partyAccountsUrlTemplateValue) {
      this.selectParty(partyId, partyName || `Party #${partyId}`)
    }
  }

  onNowServingPartyCleared() {
    this.hidePartyAccounts()
    this.selectedPartyId = null
    this.partyAccounts = []
    if (this.hasAccountSelectTarget) {
      this.accountSelectTarget.innerHTML = ""
      this.accountSelectTarget.value = ""
    }
  }

  handleFormReset() {
    this.selectedPartyId = null
    this.partyAccounts = []
    this.hideResults()
    this.hidePartyAccounts()
    if (this.hasAccountSelectTarget) {
      this.accountSelectTarget.innerHTML = ""
      this.accountSelectTarget.value = ""
    }
  }

  search(event) {
    const q = this.searchInputTarget.value.trim()
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (q.length < 1) {
      this.hideResults()
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
      const data = await response.json()
      this.renderResults(data.parties || [], data.accounts || [])
    } catch {
      this.hideResults()
    }
  }

  renderResults(parties, accounts) {
    if (!this.hasResultsListTarget) return
    const list = this.resultsListTarget
    list.innerHTML = ""
    const hasResults = parties.length > 0 || accounts.length > 0
    list.hidden = false
    if (!hasResults) {
      const empty = document.createElement("div")
      empty.className = "px-3 py-2 text-sm text-slate-500"
      empty.textContent = "No parties or accounts found"
      list.appendChild(empty)
      return
    }
    parties.forEach((p) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className = "block w-full text-left px-3 py-2 text-sm hover:bg-base-200 rounded"
      item.textContent = `${p.display_name} (Party)`
      item.dataset.partyId = p.id
      item.dataset.partyName = p.display_name
      item.addEventListener("click", () => this.selectParty(p.id, p.display_name))
      list.appendChild(item)
    })
    accounts.forEach((a) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className = "block w-full text-left px-3 py-2 text-sm hover:bg-base-200 rounded"
      item.textContent = `${a.account_number}${a.primary_owner_name ? ` — ${a.primary_owner_name}` : ""}`
      item.dataset.accountNumber = a.account_number
      item.addEventListener("click", () => this.selectAccount(a.account_number))
      list.appendChild(item)
    })
  }

  async selectParty(partyId, partyName) {
    this.isSelectingParty = true
    this.selectedPartyId = partyId
    this.searchInputTarget.value = ""
    this.hideResults()
    if (this.hasPartyNameTarget) this.partyNameTarget.textContent = partyName
    if (!this.partyAccountsUrlTemplateValue) {
      this.isSelectingParty = false
      return
    }
    try {
      const url = this.partyAccountsUrlTemplateValue.replace("__ID__", String(partyId))
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) {
        this.isSelectingParty = false
        return
      }
      this.partyAccounts = await response.json()
      this.renderPartyAccounts()
      this.showPartyAccounts()
    } catch {
      this.partyAccounts = []
      this.hidePartyAccounts()
    } finally {
      this.isSelectingParty = false
    }
  }

  renderPartyAccounts() {
    if (!this.hasAccountSelectTarget) return
    const select = this.accountSelectTarget
    select.innerHTML = ""
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Select account"
    select.appendChild(blank)
    this.partyAccounts.forEach((a) => {
      const opt = document.createElement("option")
      opt.value = a.account_number
      opt.textContent = `${a.account_number} (${a.account_type}${a.branch_code ? ` · ${a.branch_code}` : ""})`
      select.appendChild(opt)
    })
  }

  selectAccountFromDropdown(event) {
    const value = event.target.value
    if (value) this.selectAccount(value)
  }

  selectAccount(accountNumber) {
    this.searchInputTarget.value = accountNumber
    this.hideResults()
    this.hidePartyAccounts()
    this.selectedPartyId = null
    this.dispatchRecalculate()
  }

  onInputFreeTyping() {
    if (this.isSelectingParty) return
    if (this.hasPartyAccountsRowTarget && this.partyAccountsRowTarget.hidden === false) {
      this.hidePartyAccounts()
      this.selectedPartyId = null
    }
    this.dispatchRecalculate()
  }

  hideResults() {
    if (this.hasResultsListTarget) this.resultsListTarget.hidden = true
  }

  showPartyAccounts() {
    if (this.hasPartyAccountsRowTarget) this.partyAccountsRowTarget.hidden = false
  }

  hidePartyAccounts() {
    if (this.hasPartyAccountsRowTarget) this.partyAccountsRowTarget.hidden = true
  }

  dispatchRecalculate() {
    this.element.dispatchEvent(new CustomEvent("tx:changed", { bubbles: true }))
  }
}
