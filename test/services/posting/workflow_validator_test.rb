require "test_helper"

module Posting
  class WorkflowValidatorTest < ActiveSupport::TestCase
    test "returns error when transaction type is missing" do
      errors = WorkflowValidator.errors({ amount_cents: 10_000 })

      assert_includes errors, "Transaction type is required"
    end

    test "returns error when transaction type is unsupported" do
      errors = WorkflowValidator.errors({ transaction_type: "bill_payment", amount_cents: 10_000 })

      assert_includes errors, "Transaction type is not supported"
    end

    test "returns draft field errors" do
      errors = WorkflowValidator.errors({
        transaction_type: "draft",
        amount_cents: 12_000,
        draft_funding_source: "account",
        draft_amount_cents: 0,
        draft_payee_name: "",
        draft_instrument_number: "",
        draft_liability_account_reference: ""
      })

      assert_includes errors, "Draft amount must be greater than zero"
      assert_includes errors, "Payee name is required"
      assert_includes errors, "Instrument number is required"
      assert_includes errors, "Liability account reference is required"
      assert_includes errors, "Primary account reference is required"
    end

    test "returns vault transfer directional errors" do
      errors = WorkflowValidator.errors({
        transaction_type: "vault_transfer",
        amount_cents: 10_000,
        vault_transfer_direction: "vault_to_vault",
        vault_transfer_source_cash_account_reference: "cash:V01",
        vault_transfer_destination_cash_account_reference: "cash:V01",
        vault_transfer_reason_code: "other",
        vault_transfer_memo: ""
      })

      assert_includes errors, "Memo is required for Other reason code"
      assert_includes errors, "Source and destination cash account references must differ"
    end

    test "returns no errors for valid transfer" do
      errors = WorkflowValidator.errors({
        transaction_type: "transfer",
        amount_cents: 5_000,
        primary_account_reference: "acct:from",
        counterparty_account_reference: "acct:to"
      })

      assert_empty errors
    end

    test "check_cashing returns errors when id_type or id_number is blank" do
      errors = WorkflowValidator.errors({
        transaction_type: "check_cashing",
        check_amount_cents: 10_000,
        fee_cents: 0,
        amount_cents: 10_000,
        settlement_account_reference: "acct:settle",
        entries: [
          { side: "debit", account_reference: "acct:settle", amount_cents: 10_000 },
          { side: "credit", account_reference: "cash:D1", amount_cents: 10_000 }
        ]
      }, mode: :post)

      assert_includes errors, "ID type is required"
      assert_includes errors, "ID number is required"
    end

    test "check_cashing returns no ID errors when id_type and id_number present" do
      errors = WorkflowValidator.errors({
        transaction_type: "check_cashing",
        check_amount_cents: 10_000,
        fee_cents: 0,
        amount_cents: 10_000,
        settlement_account_reference: "acct:settle",
        id_type: "drivers_license",
        id_number: "DL123",
        entries: [
          { side: "debit", account_reference: "acct:settle", amount_cents: 10_000 },
          { side: "credit", account_reference: "cash:D1", amount_cents: 10_000 }
        ]
      }, mode: :post)

      assert errors.none? { |e| e.include?("ID type") }, "Should not report ID type error"
      assert errors.none? { |e| e.include?("ID number") }, "Should not report ID number error"
    end
  end
end
