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

    test "check_cashing returns errors when party_id is blank" do
      errors = WorkflowValidator.errors({
        transaction_type: "check_cashing",
        amount_cents: 10_000,
        check_items: [ { routing: "021", account: "123", number: "1", account_reference: "check:021:123:1", amount_cents: 10_000 } ],
        entries: []
      }, mode: :post)

      assert_includes errors, "Party is required"
    end

    test "check_cashing returns errors when id_type or id_number is blank and no party" do
      errors = WorkflowValidator.errors({
        transaction_type: "check_cashing",
        amount_cents: 10_000,
        party_id: "",
        check_items: [ { routing: "021", account: "123", number: "1", account_reference: "check:021:123:1", amount_cents: 10_000 } ],
        entries: []
      }, mode: :post)

      assert_includes errors, "ID type is required when no party is selected"
      assert_includes errors, "ID number is required when no party is selected"
    end

    test "check_cashing returns no ID errors when party_id present" do
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Test", is_active: true)
      errors = WorkflowValidator.errors({
        transaction_type: "check_cashing",
        amount_cents: 10_000,
        party_id: party.id,
        check_items: [ { routing: "021", account: "123", number: "1", account_reference: "check:021:123:1", amount_cents: 10_000 } ],
        entries: []
      }, mode: :post)

      assert errors.none? { |e| e.include?("ID type") }, "Should not report ID type error"
      assert errors.none? { |e| e.include?("ID number") }, "Should not report ID number error"
    end

    test "deposit returns error when cash_back exceeds total deposit" do
      errors = WorkflowValidator.errors({
        transaction_type: "deposit",
        amount_cents: 13_000,
        primary_account_reference: "acct:customer",
        cash_back_cents: 20_000,
        entries: [
          { side: "debit", account_reference: "cash:D01", amount_cents: 10_000 },
          { side: "debit", account_reference: "check:111:222:333", amount_cents: 5_000 },
          { side: "credit", account_reference: "cash:D01", amount_cents: 2_000 },
          { side: "credit", account_reference: "acct:customer", amount_cents: 13_000 }
        ]
      }, mode: :post)

      assert_includes errors, "Cash back cannot exceed total deposit"
    end

    test "deposit returns no error when cash_back within total deposit" do
      errors = WorkflowValidator.errors({
        transaction_type: "deposit",
        amount_cents: 13_000,
        primary_account_reference: "acct:customer",
        cash_back_cents: 2_000,
        entries: [
          { side: "debit", account_reference: "cash:D01", amount_cents: 10_000 },
          { side: "debit", account_reference: "check:111:222:333", amount_cents: 5_000 },
          { side: "credit", account_reference: "cash:D01", amount_cents: 2_000 },
          { side: "credit", account_reference: "acct:customer", amount_cents: 13_000 }
        ]
      }, mode: :post)

      assert errors.none? { |e| e.include?("Cash back") }, "Should not report cash back error"
    end
  end
end
