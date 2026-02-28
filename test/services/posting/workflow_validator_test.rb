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
        draft_amount_cents: 0,
        draft_fee_cents: 0,
        draft_cash_cents: 0,
        draft_account_cents: 0,
        draft_payee_name: "",
        draft_instrument_number: "",
        draft_liability_account_reference: ""
      })

      assert_includes errors, "Draft amount must be greater than zero"
      assert_includes errors, "Payee name is required"
      assert_includes errors, "Instrument number is required"
      assert_includes errors, "Liability account reference is required"
    end

    test "returns draft payment balance error when payment does not equal total due" do
      errors = WorkflowValidator.errors({
        transaction_type: "draft",
        amount_cents: 10_000,
        draft_amount_cents: 10_000,
        draft_fee_cents: 0,
        draft_cash_cents: 5_000,
        draft_account_cents: 0,
        draft_payee_name: "Payee",
        draft_instrument_number: "D-1",
        draft_liability_account_reference: "official_check:outstanding",
        primary_account_reference: "acct:customer"
      })

      assert_includes errors, "Payment (cash + checks + account) must equal total due"
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
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Transfer Party", is_active: true)
      errors = WorkflowValidator.errors({
        transaction_type: "transfer",
        amount_cents: 5_000,
        party_id: party.id,
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

      assert_includes errors, "Party is required. Use search or 'Add new non-customer' for walk-ins."
    end

    test "check_cashing returns party error when party_id is blank and no id fallback" do
      errors = WorkflowValidator.errors({
        transaction_type: "check_cashing",
        amount_cents: 10_000,
        party_id: "",
        id_type: "state_id",
        id_number: "12345678",
        check_items: [ { routing: "021", account: "123", number: "1", account_reference: "check:021:123:1", amount_cents: 10_000 } ],
        entries: []
      }, mode: :post)

      assert_includes errors, "Party is required. Use search or 'Add new non-customer' for walk-ins."
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
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "CashBack Party", is_active: true)
      errors = WorkflowValidator.errors({
        transaction_type: "deposit",
        amount_cents: 13_000,
        party_id: party.id,
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

    test "misc_receipt returns errors when type and income ref missing" do
      errors = WorkflowValidator.errors({
        transaction_type: "misc_receipt",
        amount_cents: 5_000,
        party_id: "",
        memo: "",
        misc_cash_cents: 5_000,
        misc_account_cents: 0,
        check_items: []
      })

      assert_includes errors, "Misc receipt type or income account reference is required"
    end

    test "misc_receipt returns memo required error when type has memo_required and memo is blank" do
      type = MiscReceiptType.create!(code: "feereq", label: "Fee Requiring Memo", income_account_reference: "income:test", memo_required: true)
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Misc Party", is_active: true)

      errors = WorkflowValidator.errors({
        transaction_type: "misc_receipt",
        amount_cents: 5_000,
        party_id: party.id,
        misc_receipt_type_id: type.id,
        income_account_reference: type.income_account_reference,
        memo: "",
        misc_cash_cents: 5_000,
        misc_account_cents: 0,
        cash_account_reference: "cash:D01",
        check_items: []
      }, mode: :validate)

      assert_includes errors, "Memo is required"
    end

    test "misc_receipt returns no memo error when type has memo_required false and memo is blank" do
      type = MiscReceiptType.create!(code: "feenoreq", label: "Fee No Memo", income_account_reference: "income:test", memo_required: false)
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Misc Party", is_active: true)

      errors = WorkflowValidator.errors({
        transaction_type: "misc_receipt",
        amount_cents: 5_000,
        party_id: party.id,
        misc_receipt_type_id: type.id,
        income_account_reference: type.income_account_reference,
        memo: "",
        misc_cash_cents: 5_000,
        misc_account_cents: 0,
        cash_account_reference: "cash:D01",
        check_items: []
      }, mode: :validate)

      assert_empty errors, errors.inspect
    end

    test "misc_receipt returns error when payment does not equal amount" do
      type = MiscReceiptType.create!(code: "fee1", label: "Test Fee", income_account_reference: "income:test")
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Misc Party", is_active: true)

      errors = WorkflowValidator.errors({
        transaction_type: "misc_receipt",
        amount_cents: 5_000,
        party_id: party.id,
        misc_receipt_type_id: type.id,
        income_account_reference: type.income_account_reference,
        memo: "Test",
        misc_cash_cents: 3_000,
        misc_account_cents: 0,
        check_items: []
      })

      assert_includes errors, "Payment (cash + account + checks) must equal amount"
    end

    test "misc_receipt returns no errors for valid params" do
      type = MiscReceiptType.create!(code: "fee2", label: "Test Fee 2", income_account_reference: "income:test2")
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Misc Party 2", is_active: true)

      errors = WorkflowValidator.errors({
        transaction_type: "misc_receipt",
        amount_cents: 5_000,
        party_id: party.id,
        misc_receipt_type_id: type.id,
        income_account_reference: type.income_account_reference,
        memo: "Test memo",
        misc_cash_cents: 5_000,
        misc_account_cents: 0,
        cash_account_reference: "cash:D01",
        check_items: []
      }, mode: :validate)

      assert_empty errors, errors.inspect
    end

    test "deposit returns no error when cash_back within total deposit" do
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "CashBack Party", is_active: true)
      errors = WorkflowValidator.errors({
        transaction_type: "deposit",
        amount_cents: 13_000,
        party_id: party.id,
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
