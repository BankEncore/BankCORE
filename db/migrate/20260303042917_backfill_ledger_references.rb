# frozen_string_literal: true

class BackfillLedgerReferences < ActiveRecord::Migration[8.1]
  INTERNAL_PREFIXES = %w[cash: check: income: official_check: expense: liability:].freeze
  def up
    return unless table_exists?(:ledger_references)

    seed_customer_accounts
    seed_cash_locations
    seed_income_codes
    seed_expense_codes
    seed_liability_references
    seed_historical_posting_legs
  end

  def down
    # No-op: backfill is additive; clearing would orphan references
  end

  private

  def seed_customer_accounts
    return unless table_exists?(:accounts)

    Account.find_each do |account|
      reference = "acct:#{account.account_number}"
      next if LedgerReference.exists?(reference: reference)

      LedgerReference.create!(
        reference: reference,
        ref_type: "customer_account",
        status: "active",
        account_id: account.id
      )
    end
  end

  def seed_cash_locations
    return unless table_exists?(:cash_locations)

    CashLocation.find_each do |loc|
      reference = "cash:#{loc.code}"
      next if reference == "cash:unassigned"
      next if LedgerReference.exists?(reference: reference)

      LedgerReference.create!(
        reference: reference,
        ref_type: "cash_location",
        status: "active",
        cash_location_id: loc.id
      )
    end
  end

  def seed_income_codes
    static_income = %w[
      income:check_cashing_fee
      income:transfer_fee
      income:draft_fee
      income:bill_payment_fee
      income:cash_over
      income:variance
      income:fee
    ]
    static_income.each { |ref| ensure_ledger_reference(ref, "income_code") }

    return unless table_exists?(:misc_receipt_types)

    MiscReceiptType.find_each do |mrt|
      ref = mrt.income_account_reference.to_s.strip
      next if ref.blank?
      next if LedgerReference.exists?(reference: ref)

      LedgerReference.create!(reference: ref, ref_type: "income_code", status: "active")
    end
  end

  def seed_expense_codes
    ensure_ledger_reference("expense:cash_short", "expense_code")
  end

  def seed_liability_references
    ensure_ledger_reference("official_check:outstanding", "liability")

    return unless table_exists?(:bill_payees)

    BillPayee.find_each do |bp|
      ref = bp.liability_account_reference.to_s.strip
      next if ref.blank?
      next if LedgerReference.exists?(reference: ref)

      LedgerReference.create!(reference: ref, ref_type: "liability", status: "active")
    end
  end

  def seed_historical_posting_legs
    return unless table_exists?(:posting_legs)

    refs = PostingLeg.distinct.pluck(:account_reference).compact
    refs.each do |ref|
      next if ref.blank?
      next if LedgerReference.exists?(reference: ref)

      ref_type = infer_ref_type(ref)
      LedgerReference.create!(
        reference: ref,
        ref_type: ref_type,
        status: "active",
        account_id: ref_type == "customer_account" ? find_account_id(ref) : nil,
        cash_location_id: ref_type == "cash_location" ? find_cash_location_id(ref) : nil
      )
    end
  end

  def ensure_ledger_reference(reference, ref_type)
    return if LedgerReference.exists?(reference: reference)

    LedgerReference.create!(reference: reference, ref_type: ref_type, status: "active")
  end

  def infer_ref_type(ref)
    return "check_clearing" if ref.start_with?("check:")
    return "cash_location" if ref.start_with?("cash:")
    return "income_code" if ref.start_with?("income:")
    return "expense_code" if ref.start_with?("expense:")
    return "liability" if ref.start_with?("official_check:") || ref.start_with?("liability:")
    return "customer_account" if ref.start_with?("acct:") || INTERNAL_PREFIXES.none? { |p| ref.start_with?(p) }

    "customer_account"
  end

  def find_account_id(ref)
    account_number = ref.sub(/\Aacct:/, "").strip.presence || ref
    Account.find_by(account_number: account_number)&.id
  end

  def find_cash_location_id(ref)
    code = ref.sub(/\Acash:/i, "").strip
    CashLocation.find_by(code: code)&.id
  end
end
