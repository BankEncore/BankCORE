# frozen_string_literal: true

require "test_helper"

module Posting
  class MiscAdditionLegBuilderTest < ActiveSupport::TestCase
    setup do
      @type = MiscReceiptType.create!(
        code: "mab_test",
        label: "Test Fee",
        income_account_reference: "income:test_fee",
        default_amount_cents: 500,
        memo_required: false,
        display_order: 0,
        is_active: true
      )
    end

    test "returns empty when misc_additions blank" do
      legs = MiscAdditionLegBuilder.call(
        posting_params: { transaction_type: "deposit" },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:customer"
      )
      assert_empty legs
    end

    test "returns empty for waived line" do
      legs = MiscAdditionLegBuilder.call(
        posting_params: {
          transaction_type: "deposit",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 500, waived: true }
          ]
        },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:customer"
      )
      assert_empty legs
    end

    test "returns empty for zero amount" do
      legs = MiscAdditionLegBuilder.call(
        posting_params: {
          transaction_type: "deposit",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 0 }
          ]
        },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:customer"
      )
      assert_empty legs
    end

    test "builds debit from cash for deposit" do
      legs = MiscAdditionLegBuilder.call(
        posting_params: {
          transaction_type: "deposit",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 250 }
          ]
        },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:customer"
      )
      assert_equal 2, legs.size
      debit = legs.find { |l| l[:side] == "debit" }
      credit = legs.find { |l| l[:side] == "credit" }
      assert_equal "cash:D01", debit[:account_reference]
      assert_equal 250, debit[:amount_cents]
      assert_equal "income:test_fee", credit[:account_reference]
      assert_equal 250, credit[:amount_cents]
    end

    test "builds debit from cash for draft" do
      legs = MiscAdditionLegBuilder.call(
        posting_params: {
          transaction_type: "draft",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 100 }
          ]
        },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:customer"
      )
      debit = legs.find { |l| l[:side] == "debit" }
      assert_equal "cash:D01", debit[:account_reference]
    end

    test "builds debit from primary account for draft when payment is from account only" do
      legs = MiscAdditionLegBuilder.call(
        posting_params: {
          transaction_type: "draft",
          draft_cash_cents: 0,
          draft_account_cents: 10_800,
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 800 }
          ]
        },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:10001079"
      )
      debit = legs.find { |l| l[:side] == "debit" }
      assert_equal "acct:10001079", debit[:account_reference]
      assert_equal 800, debit[:amount_cents]
    end

    test "builds debit from cash for draft when payment includes cash" do
      legs = MiscAdditionLegBuilder.call(
        posting_params: {
          transaction_type: "draft",
          draft_cash_cents: 800,
          draft_account_cents: 10_000,
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 800 }
          ]
        },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:10001079"
      )
      debit = legs.find { |l| l[:side] == "debit" }
      assert_equal "cash:D01", debit[:account_reference]
    end

    test "builds debit from primary account for transfer" do
      legs = MiscAdditionLegBuilder.call(
        posting_params: {
          transaction_type: "transfer",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 150 }
          ]
        },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:from"
      )
      debit = legs.find { |l| l[:side] == "debit" }
      assert_equal "acct:from", debit[:account_reference]
      assert_equal 150, debit[:amount_cents]
    end

    test "builds debit from primary account for check_cashing" do
      legs = MiscAdditionLegBuilder.call(
        posting_params: {
          transaction_type: "check_cashing",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 200 }
          ]
        },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:customer"
      )
      debit = legs.find { |l| l[:side] == "debit" }
      assert_equal "acct:customer", debit[:account_reference]
    end

    test "builds multiple legs for multiple misc additions" do
      type2 = MiscReceiptType.create!(
        code: "mab_test2",
        label: "Second Fee",
        income_account_reference: "income:test_fee2",
        memo_required: false,
        display_order: 1,
        is_active: true
      )
      legs = MiscAdditionLegBuilder.call(
        posting_params: {
          transaction_type: "deposit",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 100 },
            { misc_receipt_type_id: type2.id, amount_charged_cents: 200 }
          ]
        },
        default_cash_account_reference: "cash:D01",
        primary_account_reference: "acct:customer"
      )
      assert_equal 4, legs.size
      debits = legs.select { |l| l[:side] == "debit" }
      credits = legs.select { |l| l[:side] == "credit" }
      assert_equal 300, debits.sum { |l| l[:amount_cents] }
      assert_equal 300, credits.sum { |l| l[:amount_cents] }
    end
  end
end
