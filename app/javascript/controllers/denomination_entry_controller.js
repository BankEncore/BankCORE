import { Controller } from "@hotwired/stimulus"

/**
 * Denomination entry: per-denomination qty/amount inputs, subtotals, grand total.
 * Emits denomination:change with { totalCents, lines } for parent form.
 */
export default class extends Controller {
  static values = {
    catalog: Array,
    mode: { type: String, default: "optional" },
    expectedCents: { type: Number, default: 0 },
    fieldName: { type: String, default: "amount_cents" },
    omitAmountFromHidden: { type: Boolean, default: false }
  }

  static targets = [
    "hiddenFieldsContainer",
    "totalOutput",
    "rowsContainer",
    "billsSubtotal",
    "looseSubtotal",
    "rolledSubtotal",
    "grandTotal",
    "differenceDisplay"
  ]

  connect() {
    this.catalog = this.catalogValue || []
    this.mode = this.modeValue || "optional"
    this.expectedCents = parseInt(this.expectedCentsValue, 10) || 0
    this.lines = this.catalog.map((d) => ({
      cash_denomination_id: d.id,
      kind: d.kind,
      unit_value_cents: d.kind === "coin_roll" ? (d.roll_value_cents || 0) : (d.face_value_cents || 0),
      qty: 0,
      amount_cents: 0
    }))
    this.rowsContainerTarget?.addEventListener("input", this.handleInput.bind(this))
    this.rowsContainerTarget?.addEventListener("change", this.handleChange.bind(this))
    this.render()
  }

  disconnect() {
    this.rowsContainerTarget?.removeEventListener("input", this.handleInput.bind(this))
    this.rowsContainerTarget?.removeEventListener("change", this.handleChange.bind(this))
  }

  handleInput(event) {
    const input = event.target
    if (input.dataset.rowIdx == null) return
    const idx = parseInt(input.dataset.rowIdx, 10)
    const field = input.dataset.field
    if (field === "qty") this.updateFromQty(idx, input.value)
    else if (field === "amount") this.updateFromAmount(idx, input.value)
    this.recalculate()
  }

  handleChange(event) {
    const input = event.target
    if (input.dataset.rowIdx == null) return
    const idx = parseInt(input.dataset.rowIdx, 10)
    const field = input.dataset.field
    if (field === "qty") this.updateFromQty(idx, input.value)
    else if (field === "amount") this.updateFromAmount(idx, input.value)
    this.recalculate()
  }

  updateFromQty(idx, value) {
    const line = this.lines[idx]
    if (!line) return
    const qty = Math.max(0, parseInt(String(value).replace(/\D/g, ""), 10) || 0)
    line.qty = qty
    line.amount_cents = qty * line.unit_value_cents
  }

  updateFromAmount(idx, value) {
    const line = this.lines[idx]
    if (!line) return
    const cents = this.parseCents(value)
    line.amount_cents = Math.max(0, cents)
    const unit = line.unit_value_cents
    if (unit > 0) {
      if (line.kind === "bill" || line.kind === "coin_roll") {
        line.qty = line.amount_cents % unit === 0 ? line.amount_cents / unit : 0
      } else {
        line.qty = line.amount_cents % unit === 0 ? line.amount_cents / unit : 0
      }
    }
  }

  parseCents(str) {
    if (str == null || str === undefined) return 0
    const cleaned = String(str).replace(/[$,]/g, "").replace(/\s/g, "").trim()
    if (cleaned === "") return 0
    const num = parseFloat(cleaned)
    return Number.isNaN(num) ? 0 : Math.max(0, Math.round(num * 100))
  }

  formatCents(cents) {
    const v = Math.max(0, parseInt(cents, 10) || 0)
    return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(v / 100)
  }

  getState() {
    let billsTotal = 0
    let looseTotal = 0
    let rolledTotal = 0
    this.lines.forEach((line) => {
      const amt = line.amount_cents || 0
      if (line.kind === "bill") billsTotal += amt
      else if (line.kind === "coin_loose") looseTotal += amt
      else if (line.kind === "coin_roll") rolledTotal += amt
    })
    const totalCents = billsTotal + looseTotal + rolledTotal
    const lines = this.lines.filter((l) => (l.amount_cents || 0) > 0)
    return { totalCents, lines }
  }

  recalculate() {
    if (this.hasRowsContainerTarget) {
      this.rowsContainerTarget.querySelectorAll("[data-amount-display]").forEach((span) => {
        const row = span.closest("[data-row-idx]")
        const idx = parseInt(row?.dataset?.rowIdx, 10)
        const line = this.lines[idx]
        if (line) span.textContent = this.formatCents(line.amount_cents || 0)
      })
    }

    let billsTotal = 0
    let looseTotal = 0
    let rolledTotal = 0

    this.lines.forEach((line) => {
      const amt = line.amount_cents || 0
      if (line.kind === "bill") billsTotal += amt
      else if (line.kind === "coin_loose") looseTotal += amt
      else if (line.kind === "coin_roll") rolledTotal += amt
    })

    const grandTotal = billsTotal + looseTotal + rolledTotal

    if (this.hasBillsSubtotalTarget) this.billsSubtotalTarget.textContent = this.formatCents(billsTotal)
    if (this.hasLooseSubtotalTarget) this.looseSubtotalTarget.textContent = this.formatCents(looseTotal)
    if (this.hasRolledSubtotalTarget) this.rolledSubtotalTarget.textContent = this.formatCents(rolledTotal)
    if (this.hasGrandTotalTarget) this.grandTotalTarget.textContent = this.formatCents(grandTotal)

    if (this.hasDifferenceDisplayTarget) {
      if (this.expectedCents > 0) {
        const diff = grandTotal - this.expectedCents
        this.differenceDisplayTarget.textContent = diff === 0 ? "—" : diff > 0 ? `+${this.formatCents(diff)}` : this.formatCents(diff)
        this.differenceDisplayTarget.hidden = false
      } else {
        this.differenceDisplayTarget.hidden = true
      }
    }

    if (this.hasTotalOutputTarget) {
      this.totalOutputTarget.value = String(grandTotal)
      this.totalOutputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
    // When embedded in a form without totalOutput, parent listens to denomination:change and syncs amount

    if (this.hasHiddenFieldsContainerTarget) {
      this.syncHiddenFields(grandTotal)
    }

    this.element.dispatchEvent(
      new CustomEvent("denomination:change", {
        bubbles: true,
        detail: { totalCents: grandTotal, lines: this.lines.filter((l) => (l.amount_cents || 0) > 0) }
      })
    )
  }

  syncHiddenFields(grandTotal) {
    const container = this.hiddenFieldsContainerTarget
    const lines = this.lines.filter((l) => (l.amount_cents || 0) > 0)
    const fieldName = this.fieldNameValue || "amount_cents"
    const omitAmount = this.omitAmountFromHiddenValue === true
    let html = ""
    if (lines.length > 0 && grandTotal > 0 && !omitAmount) {
      html += `<input type="hidden" name="${fieldName}" value="${grandTotal}" />`
    }
    if (lines.length > 0) {
      lines.forEach((line) => {
        html += `<input type="hidden" name="denomination_lines[][cash_denomination_id]" value="${line.cash_denomination_id}" />`
        html += `<input type="hidden" name="denomination_lines[][qty]" value="${line.qty || 0}" />`
        html += `<input type="hidden" name="denomination_lines[][amount_cents]" value="${line.amount_cents || 0}" />`
      })
    }
    container.innerHTML = html
  }

  render() {
    if (!this.hasRowsContainerTarget) return

    const groups = { bill: [], coin_loose: [], coin_roll: [] }
    this.catalog.forEach((d, idx) => {
      const k = d.kind || "bill"
      if (groups[k]) groups[k].push({ ...d, idx })
    })

    const escapeHtml = (s) => {
      const div = document.createElement("div")
      div.textContent = s
      return div.innerHTML
    }

    const renderGroup = (label, items) => {
      if (items.length === 0) return ""
      let h = `<div class="font-medium text-xs text-slate-600 mb-1 mt-2">${escapeHtml(label)}</div><div class="space-y-1">`
      items.forEach((d) => {
        const line = this.lines[d.idx] || {}
        h += `
          <div class="grid grid-cols-[4rem_1fr_5rem] gap-2 items-center text-sm" data-row-idx="${d.idx}">
            <span class="text-slate-700">${escapeHtml(d.display_label)}</span>
            <input type="number" min="0" step="1" inputmode="numeric" placeholder="0" class="input input-bordered input-sm" data-field="qty" data-row-idx="${d.idx}" value="${line.qty || ""}" aria-label="Qty ${escapeHtml(d.display_label)}" />
            <span class="tabular-nums text-right mono text-slate-600" data-amount-display="">${this.formatCents(line.amount_cents || 0)}</span>
          </div>
        `
      })
      h += "</div>"
      return h
    }

    let html = ""
    html += renderGroup("Bills", groups.bill)
    html += renderGroup("Loose coin", groups.coin_loose)
    html += renderGroup("Rolled coin", groups.coin_roll)

    this.rowsContainerTarget.innerHTML = html

    this.recalculate()
  }
}
