# frozen_string_literal: true

class ApprovalThreshold < ApplicationRecord
  TRIGGER_KEYS = %w[cash_in cash_out amount vault_transfer].freeze

  validates :trigger_key, presence: true, inclusion: { in: TRIGGER_KEYS }
  validates :threshold_cents, numericality: { greater_than: 0 }
  validates :policy_trigger, presence: true

  scope :for_trigger, ->(key) { where(trigger_key: key) }
  scope :for_transaction_type, ->(type) { where(transaction_type: type.presence || "") }

  def self.find_for(trigger_key:, transaction_type:)
    specific = for_trigger(trigger_key).for_transaction_type(transaction_type).first
    return specific if specific.present?

    default = for_trigger(trigger_key).where(transaction_type: [ nil, "" ]).first
    default
  end
end
