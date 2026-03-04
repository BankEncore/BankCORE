# frozen_string_literal: true

module LedgerReferenceTestHelper
  STATIC_REFS = [
    [ "income:check_cashing_fee", "income_code" ],
    [ "income:transfer_fee", "income_code" ],
    [ "income:draft_fee", "income_code" ],
    [ "income:bill_payment_fee", "income_code" ],
    [ "income:cash_over", "income_code" ],
    [ "income:variance", "income_code" ],
    [ "income:fee", "income_code" ],
    [ "expense:cash_short", "expense_code" ],
    [ "official_check:outstanding", "liability" ]
  ].freeze

  def ensure_ledger_references_for_fixtures
    return unless LedgerReference.table_exists?

    ensure_static_refs
    sync_fixture_ledger_refs
  end

  def ensure_ledger_references_exist
    ensure_static_refs
  end

  private

  def ensure_static_refs
    STATIC_REFS.each do |reference, ref_type|
      next if LedgerReference.exists?(reference: reference)

      LedgerReference.create!(reference: reference, ref_type: ref_type, status: "active")
    end
  end

  def sync_fixture_ledger_refs
    CashLocation.find_each do |loc|
      next if loc.code == "unassigned"

      ref = "cash:#{loc.code}"
      next if LedgerReference.exists?(reference: ref)

      LedgerReference.create!(reference: ref, ref_type: "cash_location", status: "active", cash_location_id: loc.id)
    end

    Account.find_each do |acct|
      ref = "acct:#{acct.account_number}"
      next if LedgerReference.exists?(reference: ref)

      LedgerReference.create!(reference: ref, ref_type: "customer_account", status: "active", account_id: acct.id)
    end
  end
end
