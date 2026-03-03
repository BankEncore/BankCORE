# frozen_string_literal: true

module ApprovalThresholdTestHelper
  DEFAULT_THRESHOLDS = [
    [ "cash_in", 500_000, "cash_in_threshold" ],
    [ "cash_out", 100_000, "cash_out_threshold" ],
    [ "vault_transfer", 1_000_000, "vault_transfer_threshold" ],
    [ "amount", 100_000, "amount_threshold" ]
  ].freeze

  def ensure_approval_thresholds
    return unless ApprovalThreshold.table_exists?
    return if ApprovalThreshold.exists?

    DEFAULT_THRESHOLDS.each do |trigger_key, threshold_cents, policy_trigger|
      ApprovalThreshold.create!(
        trigger_key: trigger_key,
        transaction_type: "",
        threshold_cents: threshold_cents,
        policy_trigger: policy_trigger
      )
    end
  end
end
