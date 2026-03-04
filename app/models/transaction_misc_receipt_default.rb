# frozen_string_literal: true

class TransactionMiscReceiptDefault < ApplicationRecord
  OVERRIDE_POLICIES = %w[teller_override supervisor_override fixed].freeze
  SUPPORTED_TRANSACTION_TYPES = %w[deposit withdrawal transfer check_cashing draft misc_receipt bill_payment].freeze

  belongs_to :misc_receipt_type

  validates :transaction_type, presence: true, inclusion: { in: SUPPORTED_TRANSACTION_TYPES }
  validates :override_policy, presence: true, inclusion: { in: OVERRIDE_POLICIES }
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }
  validates :misc_receipt_type_id, uniqueness: { scope: :transaction_type, message: "is already linked to this transaction type" }

  scope :for_transaction_type, ->(type) { where(transaction_type: type.to_s) }
  scope :ordered, -> { order(:transaction_type, :display_order, :misc_receipt_type_id) }

  def teller_override?
    override_policy == "teller_override"
  end

  def supervisor_override?
    override_policy == "supervisor_override"
  end

  def fixed?
    override_policy == "fixed"
  end

  def effective_default_amount_cents
    default_amount_cents.presence || misc_receipt_type&.default_amount_cents
  end
end
