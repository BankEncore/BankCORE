# frozen_string_literal: true

require "test_helper"

class ApprovalThresholdTest < ActiveSupport::TestCase
  setup do
    ensure_approval_thresholds
  end

  test "validates trigger_key inclusion" do
    threshold = ApprovalThreshold.new(
      trigger_key: "invalid",
      transaction_type: "",
      threshold_cents: 100_000,
      policy_trigger: "test"
    )
    assert_not threshold.valid?
    assert_includes threshold.errors[:trigger_key], "is not included in the list"
  end

  test "validates threshold_cents greater than zero" do
    threshold = ApprovalThreshold.new(
      trigger_key: "amount",
      transaction_type: "deposit",
      threshold_cents: 0,
      policy_trigger: "amount_threshold"
    )
    assert_not threshold.valid?
    assert_includes threshold.errors[:threshold_cents], "must be greater than 0"
  end

  test "find_for returns specific override when present" do
    ApprovalThreshold.create!(
      trigger_key: "cash_in",
      transaction_type: "deposit",
      threshold_cents: 200_000,
      policy_trigger: "deposit_cash_in_threshold"
    )

    found = ApprovalThreshold.find_for(trigger_key: "cash_in", transaction_type: "deposit")
    assert_equal 200_000, found.threshold_cents
    assert_equal "deposit_cash_in_threshold", found.policy_trigger
  end

  test "find_for returns default when no specific override" do
    found = ApprovalThreshold.find_for(trigger_key: "cash_in", transaction_type: "deposit")
    assert_equal 500_000, found.threshold_cents
    assert_equal "cash_in_threshold", found.policy_trigger
  end

  test "find_for returns nil when no matching threshold" do
    ApprovalThreshold.destroy_all
    found = ApprovalThreshold.find_for(trigger_key: "cash_in", transaction_type: "deposit")
    assert_nil found
  end
end
