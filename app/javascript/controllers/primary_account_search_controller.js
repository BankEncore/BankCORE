import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput",
    "resultsList",
    "partyAccountsRow",
    "partyName",
    "accountSelect",
    "relatedPartiesRow",
    "relatedPartiesSelect"
  ]

  static values = {
    searchUrl: String,
    partyAccountsUrlTemplate: String,
    accountReferenceUrl: String,
    relatedPartiesUrlTemplate: String
  }

  connect() {
    this.searchTimeout = null
    this.resolveTypedAccountTimeout = null
    this.selectedPartyId = null
    this.selectedAccountId = null
    this.partyAccounts = []
    this.relatedParties = []
    this.isSelectingParty = false
    this.ignoreNextInputFreeTyping = false
    this.boundHandleFormReset = this.handleFormReset.bind(this)
    this.boundOnNowServingPartySelected = this.onNowServingPartySelected.bind(this)
    this.boundOnNowServingPartyCleared = this.onNowServingPartyCleared.bind(this)
    document.addEventListener("tx:form-reset", this.boundHandleFormReset)
    window.addEventListener("party-search:party-selected", this.boundOnNowServingPartySelected)
    document.addEventListener("party-search:party-cleared", this.boundOnNowServingPartyCleared)
  }

  disconnect() {
    document.removeEventListener("tx:form-reset", this.boundHandleFormReset)
    window.removeEventListener("party-search:party-selected", this.boundOnNowServingPartySelected)
    document.removeEventListener("party-search:party-cleared", this.boundOnNowServingPartyCleared)
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (this.resolveTypedAccountTimeout) clearTimeout(this.resolveTypedAccountTimeout)
  }

  onNowServingPartySelected(event) {
    const form = this.element.closest("form")
    const ilInput = form?.querySelector('[name="initiating_lookup"]')
    if (ilInput?.value === "account_first") return
    const { partyId, partyName } = event.detail || {}
    if (partyId && this.partyAccountsUrlTemplateValue) {
      this.selectParty(partyId, partyName || `Party #${partyId}`)
    }
  }

  onNowServingPartyCleared() {
    this.hidePartyAccounts()
    this.hideRelatedParties()
    this.selectedPartyId = null
    this.partyAccounts = []
    this.relatedParties = []
    if (this.hasAccountSelectTarget) {
      this.accountSelectTarget.innerHTML = ""
      this.accountSelectTarget.value = ""
    }
  }

  handleFormReset() {
    this.selectedPartyId = null
    this.selectedAccountId = null
    this.partyAccounts = []
    this.relatedParties = []
    this.setInitiatingLookup("")
    this.hideResults()
    this.hidePartyAccounts()
    this.hideRelatedParties()
    if (this.hasAccountSelectTarget) {
      this.accountSelectTarget.innerHTML = ""
      this.accountSelectTarget.value = ""
    }
    if (this.hasRelatedPartiesSelectTarget) {
      this.relatedPartiesSelectTarget.innerHTML = ""
      this.relatedPartiesSelectTarget.value = ""
    }
  }

  search(event) {
    const q = this.searchInputTarget.value.trim()
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (this.resolveTypedAccountTimeout) clearTimeout(this.resolveTypedAccountTimeout)
    if (q.length < 1) {
      this.hideResults()
      return
    }
    this.searchTimeout = setTimeout(() => this.fetchSearch(q), 200)
    this.resolveTypedAccountTimeout = setTimeout(() => this.resolveTypedAccount(), 500)
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
      const accounts = data.accounts || []
      const parties = data.parties || []
      const qTrim = q.trim()
      const exactAccount = accounts.find((a) => String(a.account_number).trim() === qTrim)
      if (exactAccount && accounts.length === 1) {
        this.selectAccount(exactAccount.account_number, exactAccount.id)
        return
      }
      this.renderResults(parties, accounts)
      this.resolveTypedAccount()
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
      item.dataset.accountId = a.id
      item.addEventListener("click", () => this.selectAccount(a.account_number, a.id))
      list.appendChild(item)
    })
  }

  async   setInitiatingLookup(value) {
    const form = this.element.closest("form")
    const input = form?.querySelector('[name="initiating_lookup"]')
    if (input) input.value = value || ""
  }

  async selectParty(partyId, partyName) {
    this.isSelectingParty = true
    this.ignoreNextInputFreeTyping = true
    this.selectedPartyId = partyId
    this.setInitiatingLookup("party_first")
    this.searchInputTarget.value = ""
    this.hideResults()
    if (this.hasPartyNameTarget) this.partyNameTarget.textContent = partyName
    if (!this.partyAccountsUrlTemplateValue) {
      this.isSelectingParty = false
      this.ignoreNextInputFreeTyping = false
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
        this.ignoreNextInputFreeTyping = false
        return
      }
      this.partyAccounts = await response.json()
      this.renderPartyAccounts()
      this.showPartyAccounts()
    } catch {
      this.partyAccounts = []
      this.hidePartyAccounts()
      this.ignoreNextInputFreeTyping = false
    } finally {
      // Defer reset so any input event from programmatic value="" is processed first
      // while flags are still set, preventing onInputFreeTyping from hiding the row
      setTimeout(() => {
        this.isSelectingParty = false
        this.ignoreNextInputFreeTyping = false
      }, 0)
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
      opt.dataset.accountId = a.id
      const relLabel = a.relationship_type ? ` — ${a.relationship_type}` : ""
      opt.textContent = `${a.account_number} (${a.account_type}${a.branch_code ? ` · ${a.branch_code}` : ""})${relLabel}`
      select.appendChild(opt)
    })
  }

  selectAccountFromDropdown(event) {
    const opt = event.target.selectedOptions?.[0]
    const value = event.target.value
    const accountId = opt?.dataset?.accountId
    if (value) this.selectAccount(value, accountId ? parseInt(accountId, 10) : null)
  }

  selectAccount(accountNumber, accountId = null) {
    this.searchInputTarget.value = accountNumber
    this.hideResults()
    this.hidePartyAccounts()
    if (!this.selectedPartyId) this.setInitiatingLookup("account_first")
    this.selectedPartyId = null
    this.selectedAccountId = accountId
    if (accountId && this.hasRelatedPartiesUrlTemplateValue) {
      this.fetchRelatedParties(accountId)
    } else {
      this.hideRelatedParties()
    }
    this.dispatchRecalculate()
  }

  async fetchRelatedParties(accountId) {
    if (!this.relatedPartiesUrlTemplateValue) return
    try {
      const url = this.relatedPartiesUrlTemplateValue.replace("__ID__", String(accountId))
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      this.relatedParties = await response.json()
      if (!response.ok) {
        this.relatedParties = []
        this.hideRelatedParties()
        return
      }
      this.renderRelatedParties()
      if (this.relatedParties.length > 0 && this.hasRelatedPartiesRowTarget) {
        this.showRelatedParties()
      } else {
        this.hideRelatedParties()
      }
    } catch {
      this.relatedParties = []
      this.hideRelatedParties()
    }
  }

  renderRelatedParties() {
    if (!this.hasRelatedPartiesSelectTarget) return
    const select = this.relatedPartiesSelectTarget
    select.innerHTML = ""
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Select party"
    select.appendChild(blank)
    this.relatedParties.forEach((p) => {
      const opt = document.createElement("option")
      opt.value = p.id
      opt.dataset.partyId = p.id
      opt.dataset.partyDisplayName = p.display_name
      opt.textContent = `${p.display_name}${p.relationship_type ? ` — ${p.relationship_type}` : ""}`
      select.appendChild(opt)
    })
  }

  selectRelatedPartyFromDropdown(event) {
    const opt = event.target.selectedOptions?.[0]
    const value = event.target.value
    if (!value) return
    const partyId = opt?.dataset?.partyId
    const displayName = opt?.dataset?.partyDisplayName || opt?.textContent
    if (partyId) this.applyRelatedParty({ id: parseInt(partyId, 10), display_name: displayName })
  }

  applyRelatedParty(p) {
    this.setInitiatingLookup("account_first")
    document.dispatchEvent(
      new CustomEvent("apply-last-party", {
        bubbles: true,
        detail: { id: p.id, display_name: p.display_name }
      })
    )
  }

  showRelatedParties() {
    if (this.hasRelatedPartiesRowTarget) this.relatedPartiesRowTarget.hidden = false
  }

  hideRelatedParties() {
    this.relatedParties = []
    this.selectedAccountId = null
    if (this.hasRelatedPartiesRowTarget) this.relatedPartiesRowTarget.hidden = true
    if (this.hasRelatedPartiesSelectTarget) {
      this.relatedPartiesSelectTarget.innerHTML = ""
      this.relatedPartiesSelectTarget.value = ""
    }
  }

  async onPrimaryAccountBlur() {
    await this.resolveTypedAccount()
  }

  async resolveTypedAccount() {
    if (this.resolveTypedAccountTimeout) {
      clearTimeout(this.resolveTypedAccountTimeout)
      this.resolveTypedAccountTimeout = null
    }
    const ref = this.searchInputTarget.value?.trim()
    if (!ref || !this.hasRelatedPartiesUrlTemplateValue || !this.accountReferenceUrlValue) return
    if (this.selectedAccountId != null) return
    try {
      const url = new URL(this.accountReferenceUrlValue, window.location.origin)
      url.searchParams.set("reference", ref)
      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      const data = await response.json()
      const accountId = data.account_id
      if (!response.ok) return
      if (accountId) {
        this.selectedAccountId = accountId
        this.setInitiatingLookup("account_first")
        this.hideResults()
        this.fetchRelatedParties(accountId)
        this.dispatchRecalculate()
      } else {
        this.hideRelatedParties()
      }
    } catch {
      this.hideRelatedParties()
    }
  }

  onInputFreeTyping() {
    if (this.ignoreNextInputFreeTyping) {
      this.ignoreNextInputFreeTyping = false
      return
    }
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
