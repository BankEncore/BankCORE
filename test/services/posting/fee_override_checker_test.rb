# frozen_string_literal: true

require "test_helper"

module Posting
  class FeeOverrideCheckerTest < ActiveSupport::TestCase
    setup do
      @type = MiscReceiptType.create!(
        code: "foc_test",
        label: "Test Fee",
        income_account_reference: "income:test",
        default_amount_cents: 500,
        memo_required: false,
        display_order: 0,
        is_active: true
      )
    end

    test "returns nil when misc_additions blank" do
      result = FeeOverrideChecker.call(
        posting_params: { transaction_type: "deposit" }
      )
      assert_nil result
    end

    test "returns nil for teller_override policy even when amount changed" do
      TransactionMiscReceiptDefault.create!(
        misc_receipt_type: @type,
        transaction_type: "deposit",
        override_policy: "teller_override",
        default_amount_cents: 500,
        display_order: 0
      )
      result = FeeOverrideChecker.call(
        posting_params: {
          transaction_type: "deposit",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 0, default_amount_cents: 500, waived: true }
          ]
        }
      )
      assert_nil result
    end

    test "returns approval required for supervisor_override when waived" do
      TransactionMiscReceiptDefault.create!(
        misc_receipt_type: @type,
        transaction_type: "deposit",
        override_policy: "supervisor_override",
        default_amount_cents: 500,
        display_order: 0
      )
      result = FeeOverrideChecker.call(
        posting_params: {
          transaction_type: "deposit",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 0, default_amount_cents: 500, waived: true }
          ]
        }
      )
      assert result.present?
      assert_equal "fee_override", result[:policy_trigger]
      assert result[:context][:waived]
    end

    test "returns approval required for supervisor_override when amount changed" do
      TransactionMiscReceiptDefault.create!(
        misc_receipt_type: @type,
        transaction_type: "deposit",
        override_policy: "supervisor_override",
        default_amount_cents: 500,
        display_order: 0
      )
      result = FeeOverrideChecker.call(
        posting_params: {
          transaction_type: "deposit",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 250, default_amount_cents: 500, waived: false }
          ]
        }
      )
      assert result.present?
      assert_equal "fee_override", result[:policy_trigger]
      assert_equal 250, result[:context][:amount_charged_cents]
      assert_equal 500, result[:context][:default_amount_cents]
    end

    test "returns nil for supervisor_override when amount matches default" do
      TransactionMiscReceiptDefault.create!(
        misc_receipt_type: @type,
        transaction_type: "deposit",
        override_policy: "supervisor_override",
        default_amount_cents: 500,
        display_order: 0
      )
      result = FeeOverrideChecker.call(
        posting_params: {
          transaction_type: "deposit",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 500, default_amount_cents: 500, waived: false }
          ]
        }
      )
      assert_nil result
    end

    test "returns nil when no default for misc_receipt_type" do
      result = FeeOverrideChecker.call(
        posting_params: {
          transaction_type: "deposit",
          misc_additions: [
            { misc_receipt_type_id: @type.id, amount_charged_cents: 0, waived: true }
          ]
        }
      )
      assert_nil result
    end
  end
end
