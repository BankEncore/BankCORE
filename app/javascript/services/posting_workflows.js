/**
 * Workflow config and policy helpers per transaction type.
 * Schema overrides (from workflow schema API) can be passed to resolve policies.
 */

const FALLBACK_AMOUNT_INPUT_MODES = {
  check_cashing: "check_cashing_net_payout",
  draft: "draft_amount"
}

const FALLBACK_EFFECTIVE_AMOUNT_SOURCE = {
  deposit: "cash_plus_checks",
  check_cashing: "check_cashing_net_payout"
}

const FALLBACK_CASH_IMPACT_PROFILES = {
  deposit: "inflow",
  withdrawal: "outflow",
  check_cashing: "outflow",
  draft: "draft_funding",
  vault_transfer: "vault_directional"
}

const FALLBACK_PRIMARY_ACCOUNT_POLICY = {
  draft: "draft_account_only",
  check_cashing: "never",
  vault_transfer: "never"
}

const FALLBACK_CASH_ACCOUNT_POLICY = {
  transfer: "never",
  vault_transfer: "never",
  draft: "draft_cash_only"
}

const FALLBACK_SECTIONS = {
  deposit: ["checks"],
  draft: ["draft", "checks"],
  transfer: ["transfer"],
  vault_transfer: ["vault_transfer"],
  check_cashing: ["check_cashing"]
}

export function getSections(transactionType, schema) {
  const sections = schema?.[transactionType]?.ui_sections
  return Array.isArray(sections) ? sections : []
}

export function getEntryProfile(transactionType, schema) {
  const profile = schema?.[transactionType]?.entry_profile
  return profile ?? transactionType
}

export function getAmountInputMode(transactionType, schema) {
  const mode = schema?.[transactionType]?.amount_input_mode
  return mode ?? FALLBACK_AMOUNT_INPUT_MODES[transactionType] ?? "manual"
}

export function getEffectiveAmountSource(transactionType, schema) {
  const source = schema?.[transactionType]?.effective_amount_source
  return source ?? FALLBACK_EFFECTIVE_AMOUNT_SOURCE[transactionType] ?? "amount_field"
}

export function getCashImpactProfile(transactionType, schema) {
  const profile = schema?.[transactionType]?.cash_impact_profile
  return profile ?? FALLBACK_CASH_IMPACT_PROFILES[transactionType] ?? "none"
}

export function getPrimaryAccountPolicy(transactionType, schema) {
  const policy = schema?.[transactionType]?.primary_account_policy
  return policy ?? FALLBACK_PRIMARY_ACCOUNT_POLICY[transactionType] ?? "always"
}

export function getRequiresPrimaryAccount(transactionType, schema, context = {}) {
  const policy = getPrimaryAccountPolicy(transactionType, schema)
  if (policy === "never") return false
  if (policy === "draft_account_only") {
    const draftAccountCents = context.draftAccountCents ?? 0
    return transactionType === "draft" && draftAccountCents > 0
  }
  return true
}

export function getRequiresCounterpartyAccount(transactionType, schema) {
  const value = schema?.[transactionType]?.requires_counterparty_account
  if (value !== undefined) return value === true
  return transactionType === "transfer"
}

export function getCashAccountPolicy(transactionType, schema) {
  const policy = schema?.[transactionType]?.cash_account_policy
  return policy ?? FALLBACK_CASH_ACCOUNT_POLICY[transactionType] ?? "always"
}

export function getRequiresCashAccount(transactionType, schema, context = {}) {
  const policy = getCashAccountPolicy(transactionType, schema)
  if (policy === "never") return false
  if (policy === "draft_cash_only") {
    const draftCashCents = context.draftCashCents ?? 0
    return transactionType === "draft" && draftCashCents > 0
  }
  return true
}

export function getRequiresSettlementAccount(transactionType, schema) {
  const value = schema?.[transactionType]?.requires_settlement_account
  if (value !== undefined) return value === true
  return false
}

export function getRequiresParty(transactionType, schema) {
  const workflow = schema?.[transactionType]
  if (workflow?.requires_served_party) return true
  const required = workflow?.required_fields
  if (Array.isArray(required)) return required.includes("party_id")
  return transactionType === "check_cashing"
}

export function hasSection(transactionType, sectionKey, schemaSectionsOrSchema) {
  const sections = Array.isArray(schemaSectionsOrSchema)
    ? schemaSectionsOrSchema
    : getSections(transactionType, schemaSectionsOrSchema)
  if (sections.length > 0) return sections.includes(sectionKey)
  return (FALLBACK_SECTIONS[transactionType] || []).includes(sectionKey)
}

/**
 * Pure helper: compute vault transfer details from from/to refs and drawer ref.
 */
export function vaultTransferDetailsFromState(state) {
  const fromRef = (state.vaultTransferFromReference ?? "").trim()
  const toRef = (state.vaultTransferToReference ?? "").trim()
  const drawerRef = (state.drawerReference ?? state.cashAccountReference ?? "").trim()
  const reasonCode = (state.vaultTransferReasonCode ?? "").trim()
  const memo = (state.vaultTransferMemo ?? "").trim()

  let direction = ""
  if (fromRef && toRef && fromRef !== toRef) {
    const fromIsDrawer = fromRef === drawerRef
    const toIsDrawer = toRef === drawerRef
    if (fromIsDrawer && !toIsDrawer) direction = "drawer_to_vault"
    else if (!fromIsDrawer && toIsDrawer) direction = "vault_to_drawer"
    else if (!fromIsDrawer && !toIsDrawer) direction = "vault_to_vault"
  }

  const valid = direction.length > 0 && fromRef.length > 0 && toRef.length > 0
  return {
    direction,
    sourceReference: fromRef,
    destinationReference: toRef,
    reasonCode,
    memo,
    valid
  }
}

/**
 * Returns the first blocked reason string, or "" if none.
 */
export function blockedReason({
  totalAmountCents,
  hasPrimaryAccount,
  requiresPrimaryAccount,
  requiresCounterparty,
  hasCounterparty,
  requiresCashAccount,
  hasCashAccount,
  requiresSettlementAccount,
  hasSettlementAccount,
  requiresParty,
  hasParty,
  requiresDraftDetails,
  hasDraftPayee,
  hasDraftInstrumentNumber,
  hasDraftLiabilityAccount,
  requiresVaultTransferDetails,
  hasVaultDirection,
  hasVaultReasonCode,
  hasVaultMemo,
  hasVaultEndpoints,
  hasInvalidCheckRows,
  hasInvalidCheckCashingFields,
  hasInvalidDraftFields,
  hasInvalidTransferFields,
  hasInvalidVaultTransferFields,
  balanced
}) {
  if (totalAmountCents <= 0) return "Amount must be greater than zero."
  if (requiresPrimaryAccount && !hasPrimaryAccount) return "Primary account reference is required."
  if (requiresCounterparty && !hasCounterparty) return "Counterparty account reference is required."
  if (requiresSettlementAccount && !hasSettlementAccount) return "Settlement account reference is required."
  if (requiresParty && !hasParty) return "Party is required. Use search or Add new non-customer for walk-ins."
  if (requiresCashAccount && !hasCashAccount) return "Cash account reference is required."
  if (hasInvalidCheckRows) return "Complete check routing, account, and number for each entered check."
  if (hasInvalidCheckCashingFields) return "Complete party, check amounts, and ID (when no party selected)."
  if (requiresDraftDetails && (!hasDraftPayee || !hasDraftInstrumentNumber || !hasDraftLiabilityAccount)) return "Complete draft payee and instrument details."
  if (requiresVaultTransferDetails && (!hasVaultDirection || !hasVaultReasonCode || !hasVaultMemo || !hasVaultEndpoints)) return "Complete vault transfer direction, locations, and reason details."
  if (hasInvalidDraftFields) return "Draft amount and fee values are invalid."
  if (hasInvalidTransferFields) return "Transfer fee cannot exceed transfer amount."
  if (hasInvalidVaultTransferFields) return "Vault transfer details are invalid."
  if (!balanced) return "Entries are out of balance."
  return ""
}
