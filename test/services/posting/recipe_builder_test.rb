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
  end
end
