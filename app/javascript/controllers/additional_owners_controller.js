import { Controller } from "@hotwired/stimulus"

/**
 * Manages the "Add owner" flow for account forms. Listens for party-search:party-selected
 * when context is "additional", adds the party to the list, and clears the search.
 */
export default class extends Controller {
  static targets = ["list", "searchWrapper"]

  connect() {
    this.boundOnPartySelected = this.onPartySelected.bind(this)
    window.addEventListener("party-search:party-selected", this.boundOnPartySelected)
  }

  disconnect() {
    window.removeEventListener("party-search:party-selected", this.boundOnPartySelected)
  }

  onPartySelected(event) {
    if (event.detail?.context !== "additional") return
    const { partyId, partyName } = event.detail
    if (!partyId) return

    this.addOwner(partyId, partyName || `Party #${partyId}`)
    this.clearSearch()
  }

  addOwner(partyId, displayName) {
    const form = this.element.closest("form")
    if (!form || !this.hasListTarget) return

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = "account[party_ids][]"
    hidden.value = String(partyId)

    const row = document.createElement("div")
    row.className = "flex items-center gap-2 py-1"
    row.dataset.additionalOwnerRow = partyId
    row.innerHTML = `
      <span class="text-sm flex-1">${this.escapeHtml(displayName)}</span>
      <button type="button" class="btn btn-ghost btn-xs" data-action="click->additional-owners#removeOwner">Remove</button>
    `
    row.querySelector("button").dataset.partyId = partyId
    row.appendChild(hidden)

    this.listTarget.appendChild(row)
  }

  removeOwner(event) {
    const btn = event.currentTarget
    const row = btn.closest("[data-additional-owner-row]")
    if (row) row.remove()
  }

  clearSearch() {
    if (!this.hasSearchWrapperTarget) return
    const hidden = this.searchWrapperTarget.querySelector("input[type='hidden']")
    const text = this.searchWrapperTarget.querySelector("input[type='text']")
    if (hidden) hidden.value = ""
    if (text) text.value = ""
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
