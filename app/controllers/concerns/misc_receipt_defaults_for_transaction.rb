# frozen_string_literal: true

module MiscReceiptDefaultsForTransaction
  extend ActiveSupport::Concern

  private
    def set_misc_receipt_defaults_for_transaction
      type = @transaction_type.to_s.presence
      return unless TransactionMiscReceiptDefault::SUPPORTED_TRANSACTION_TYPES.include?(type)

      @misc_receipt_defaults = TransactionMiscReceiptDefault
        .for_transaction_type(type)
        .includes(:misc_receipt_type)
        .order(:display_order)
    end
end
