# frozen_string_literal: true

require "test_helper"

module Posting
  class ApprovalThresholdCheckerTest < ActiveSupport::TestCase
    setup do
      ensure_approval_thresholds
    end

    test "returns nil when amount below threshold for deposit" do
      entries = [
        { side: "debit", account_reference: "cash:VDR1", amount_cents: 100_000 },
        { side: "credit", account_reference: "acct:customer", amount_cents: 100_000 }
      ]
      result = ApprovalThresholdChecker.call(
        posting_params: { transaction_type: "deposit", amount_cents: 100_000 },
        entries: entries,
        default_cash_account_reference: "cash:VDR1"
      )
      assert_nil result
    end

    test "returns policy trigger when cash-in exceeds threshold for deposit" do
      entries = [
        { side: "debit", account_reference: "cash:VDR1", amount_cents: 600_000 },
        { side: "credit", account_reference: "acct:customer", amount_cents: 600_000 }
      ]
      result = ApprovalThresholdChecker.call(
        posting_params: { transaction_type: "deposit", amount_cents: 600_000 },
        entries: entries,
        default_cash_account_reference: "cash:VDR1"
      )
      assert_equal "cash_in_threshold", result[:policy_trigger]
      assert_equal 500_000, result[:threshold_cents]
      assert_equal 600_000, result[:amount_cents]
    end

    test "returns policy trigger when cash-out exceeds threshold for withdrawal" do
      entries = [
        { side: "debit", account_reference: "acct:customer", amount_cents: 150_000 },
        { side: "credit", account_reference: "cash:VDR1", amount_cents: 150_000 }
      ]
      result = ApprovalThresholdChecker.call(
        posting_params: { transaction_type: "withdrawal", amount_cents: 150_000 },
        entries: entries,
        default_cash_account_reference: "cash:VDR1"
      )
      assert_equal "cash_out_threshold", result[:policy_trigger]
      assert_equal 100_000, result[:threshold_cents]
      assert_equal 150_000, result[:amount_cents]
    end

    test "returns policy trigger when amount exceeds threshold for transfer" do
      entries = [
        { side: "debit", account_reference: "acct:from", amount_cents: 150_000 },
        { side: "credit", account_reference: "acct:to", amount_cents: 150_000 }
      ]
      result = ApprovalThresholdChecker.call(
        posting_params: { transaction_type: "transfer", amount_cents: 150_000 },
        entries: entries,
        default_cash_account_reference: "cash:VDR1"
      )
      assert_equal "amount_threshold", result[:policy_trigger]
      assert_equal 100_000, result[:threshold_cents]
      assert_equal 150_000, result[:amount_cents]
    end

    test "returns policy trigger when vault transfer exceeds threshold" do
      entries = [
        { side: "debit", account_reference: "cash:VLT1", amount_cents: 1_500_000 },
        { side: "credit", account_reference: "cash:VDR1", amount_cents: 1_500_000 }
      ]
      result = ApprovalThresholdChecker.call(
        posting_params: { transaction_type: "vault_transfer", amount_cents: 1_500_000 },
        entries: entries,
        default_cash_account_reference: "cash:VDR1"
      )
      assert_equal "vault_transfer_threshold", result[:policy_trigger]
      assert_equal 1_000_000, result[:threshold_cents]
      assert_equal 1_500_000, result[:amount_cents]
    end

    test "uses amount trigger for draft with no cash legs" do
      entries = [
        { side: "debit", account_reference: "acct:customer", amount_cents: 150_000 },
        { side: "credit", account_reference: "official_check:outstanding", amount_cents: 150_000 }
      ]
      result = ApprovalThresholdChecker.call(
        posting_params: { transaction_type: "draft", amount_cents: 150_000 },
        entries: entries,
        default_cash_account_reference: "cash:VDR1"
      )
      assert_equal "amount_threshold", result[:policy_trigger]
      assert_equal 150_000, result[:amount_cents]
    end
  end
end
