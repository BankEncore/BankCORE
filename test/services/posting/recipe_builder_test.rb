require "test_helper"

module Posting
  class RecipeBuilderTest < ActiveSupport::TestCase
    test "builds deposit metadata for positive check items" do
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "deposit",
          check_items: [
            { routing: "111", account: "222", number: "333", account_reference: "check:111:222:333", amount_cents: 4_000, check_type: "on_us", hold_reason: "exception", hold_until: "2026-02-23" },
            { routing: "999", account: "888", number: "777", account_reference: "check:999:888:777", amount_cents: 0 }
          ]
        },
        default_cash_account_reference: "cash:D01"
      )

      metadata = builder.posting_metadata
      assert_equal 1, metadata.fetch(:check_items).size
      assert_equal "111", metadata[:check_items][0][:routing]
      assert_equal 4_000, metadata[:check_items][0][:amount_cents]
      assert_equal "on_us", metadata[:check_items][0][:check_type]
      assert_equal "exception", metadata[:check_items][0][:hold_reason]
    end

    test "defaults check_type to transit when blank" do
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "deposit",
          check_items: [
            { routing: "111", account: "222", number: "333", account_reference: "check:111:222:333", amount_cents: 1_000 }
          ]
        },
        default_cash_account_reference: "cash:D01"
      )

      metadata = builder.posting_metadata
      assert_equal "transit", metadata[:check_items][0][:check_type]
    end

    test "assigns check_type by position when multiple checks share same account_reference" do
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "deposit",
          amount_cents: 3_000,
          primary_account_reference: "acct:123",
          check_items: [
            { routing: "021", account: "456", number: "100", account_reference: "check:021:456:100", amount_cents: 1_000, check_type: "transit" },
            { routing: "021", account: "456", number: "100", account_reference: "check:021:456:100", amount_cents: 2_000, check_type: "on_us" }
          ],
          entries: [
            { side: "debit", account_reference: "check:021:456:100", amount_cents: 1_000 },
            { side: "debit", account_reference: "check:021:456:100", amount_cents: 2_000 },
            { side: "credit", account_reference: "acct:123", amount_cents: 3_000 }
          ]
        },
        default_cash_account_reference: "cash:D01"
      )

      entries = builder.normalized_entries
      check_entries = entries.select { |e| e[:account_reference].to_s.start_with?("check:") }
      assert_equal "transit", check_entries[0][:check_type], "First check should be transit"
      assert_equal "on_us", check_entries[1][:check_type], "Second check should be on_us"
    end

    test "builds vault transfer generated entries" do
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "vault_transfer",
          amount_cents: 5_000,
          vault_transfer_direction: "drawer_to_vault",
          vault_transfer_destination_cash_account_reference: "cash:V01"
        },
        default_cash_account_reference: "cash:D01"
      )

      entries = builder.normalized_entries
      assert_equal 2, entries.size
      assert_equal "cash_location", entries[0][:reference_type]
      assert_equal "V01", entries[0][:reference_identifier]
      assert_equal({ side: "debit", account_reference: "cash:V01", amount_cents: 5_000 }, entries[0].slice(:side, :account_reference, :amount_cents))
      assert_equal "cash_location", entries[1][:reference_type]
      assert_equal "D01", entries[1][:reference_identifier]
      assert_equal({ side: "credit", account_reference: "cash:D01", amount_cents: 5_000 }, entries[1].slice(:side, :account_reference, :amount_cents))
    end

    test "builds deposit metadata with cash_back_cents" do
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "deposit",
          amount_cents: 10_000,
          cash_back_cents: 3_000
        },
        default_cash_account_reference: "cash:D01"
      )

      metadata = builder.posting_metadata
      assert_equal 3_000, metadata[:cash_back_cents]
    end

    test "normalizes explicit deposit debit entries to drawer cash unless check" do
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "deposit",
          amount_cents: 7_000,
          primary_account_reference: "acct:customer",
          entries: [
            { side: "debit", account_reference: "cash:spoofed", amount_cents: 2_000 },
            { side: "debit", account_reference: "check:111:222:333", amount_cents: 5_000 }
          ]
        },
        default_cash_account_reference: "cash:D01"
      )

      entries = builder.normalized_entries
      assert_equal "cash:D01", entries[0][:account_reference]
      assert_equal "check:111:222:333", entries[1][:account_reference]
      assert_equal "customer_account", entries.last[:reference_type]
      assert_equal "customer", entries.last[:reference_identifier]
      assert_equal({ side: "credit", account_reference: "acct:customer", amount_cents: 7_000 }, entries.last.slice(:side, :account_reference, :amount_cents))
    end

    test "builds bill_payment generated entries with balanced legs" do
      payee = BillPayee.create!(code: "BP_RECIPE", name: "Recipe Payee", liability_account_reference: "liability:BP_RECIPE", memo_required: false, is_active: true)
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "bill_payment",
          party_id: 1,
          payee_id: payee.id,
          payee_reference: "REF001",
          payment_cents: 10_000,
          fee_cents: 250,
          bill_payment_cash_cents: 10_250,
          bill_payment_account_cents: 0,
          liability_account_reference: payee.liability_account_reference,
          primary_account_reference: "",
          cash_account_reference: "cash:D01",
          check_items: []
        },
        default_cash_account_reference: "cash:D01"
      )

      entries = builder.normalized_entries
      debit_total = entries.select { |e| e[:side] == "debit" }.sum { |e| e[:amount_cents] }
      credit_total = entries.select { |e| e[:side] == "credit" }.sum { |e| e[:amount_cents] }

      assert_equal debit_total, credit_total, "Bill payment entries must balance"
      assert entries.any? { |e| e[:account_reference] == "cash:D01" && e[:side] == "debit" && e[:amount_cents] == 10_250 }
      assert entries.any? { |e| e[:account_reference] == "liability:BP_RECIPE" && e[:side] == "credit" && e[:amount_cents] == 10_000 }
      assert entries.any? { |e| e[:account_reference] == "income:bill_payment_fee" && e[:side] == "credit" && e[:amount_cents] == 250 }
    end

    test "appends misc addition legs to deposit entries and remains balanced" do
      type = MiscReceiptType.create!(
        code: "recipe_misc",
        label: "Recipe Misc Fee",
        income_account_reference: "income:recipe_misc",
        memo_required: false,
        display_order: 0,
        is_active: true
      )
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "deposit",
          amount_cents: 10_000,
          primary_account_reference: "acct:customer",
          misc_additions: [
            { misc_receipt_type_id: type.id, amount_charged_cents: 500, default_amount_cents: 500, waived: false }
          ]
        },
        default_cash_account_reference: "cash:D01"
      )

      entries = builder.normalized_entries
      debit_total = entries.select { |e| e[:side] == "debit" }.sum { |e| e[:amount_cents] }
      credit_total = entries.select { |e| e[:side] == "credit" }.sum { |e| e[:amount_cents] }

      assert_equal debit_total, credit_total, "Entries must balance"
      assert entries.any? { |e| e[:account_reference] == "income:recipe_misc" && e[:amount_cents] == 500 }
    end

    test "includes misc_additions in posting_metadata" do
      type = MiscReceiptType.create!(
        code: "recipe_meta",
        label: "Meta Fee",
        income_account_reference: "income:meta",
        memo_required: false,
        display_order: 0,
        is_active: true
      )
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "deposit",
          amount_cents: 5_000,
          primary_account_reference: "acct:customer",
          misc_additions: [
            { misc_receipt_type_id: type.id, amount_charged_cents: 250, default_amount_cents: 250, waived: false }
          ]
        },
        default_cash_account_reference: "cash:D01"
      )

      metadata = builder.posting_metadata
      assert metadata.key?(:misc_additions)
      items = metadata[:misc_additions]
      assert_equal 1, items.size
      assert_equal type.id, items[0][:misc_receipt_type_id]
      assert_equal "Meta Fee", items[0][:type_label]
      assert_equal 250, items[0][:amount_charged_cents]
      assert_equal false, items[0][:waived]
    end

    test "builds bill_payment metadata with payee snapshot" do
      payee = BillPayee.create!(code: "BP_META", name: "Meta Payee", liability_account_reference: "liability:BP_META", memo_required: true, is_active: true)
      builder = RecipeBuilder.new(
        posting_params: {
          transaction_type: "bill_payment",
          party_id: 1,
          payee_id: payee.id,
          payee_reference: "REF_META",
          payment_cents: 5_000,
          fee_cents: 0,
          bill_payment_cash_cents: 5_000,
          bill_payment_account_cents: 0,
          liability_account_reference: payee.liability_account_reference,
          memo: "Test memo",
          check_items: []
        },
        default_cash_account_reference: "cash:D01"
      )

      metadata = builder.posting_metadata
      bp = metadata[:bill_payment]
      assert_equal payee.id.to_s, bp[:payee_id]
      assert_equal "BP_META", bp[:payee_code]
      assert_equal "Meta Payee", bp[:payee_name]
      assert_equal "REF_META", bp[:payee_reference]
      assert_equal 5_000, bp[:payment_cents]
      assert_equal 0, bp[:fee_cents]
      assert_equal 5_000, bp[:total_cents]
    end
  end
end
