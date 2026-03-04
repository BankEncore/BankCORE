# frozen_string_literal: true

module Posting
  class FeeOverrideChecker
    def self.call(posting_params:)
      new(posting_params: posting_params).call
    end

    def initialize(posting_params:)
      @posting_params = posting_params.to_h.symbolize_keys
    end

    def call
      misc_additions.each do |line|
        result = check_line(line)
        return result if result.present?
      end
      nil
    end

    private
      attr_reader :posting_params

      def misc_additions
        raw = posting_params[:misc_additions] || posting_params["misc_additions"]
        Array(raw).map { |e| e.to_h.symbolize_keys }
      end

      def check_line(line)
        type_id = (line[:misc_receipt_type_id] || line["misc_receipt_type_id"]).to_s.presence
        return nil if type_id.blank?

        default = TransactionMiscReceiptDefault.find_by(
          transaction_type: transaction_type,
          misc_receipt_type_id: type_id
        )
        return nil if default.blank?
        return nil if default.teller_override?
        return nil unless override_detected?(line, default)

        if default.supervisor_override?
          return {
            policy_trigger: "fee_override",
            context: {
              misc_receipt_type_id: type_id.to_i,
              default_amount_cents: default.effective_default_amount_cents,
              amount_charged_cents: amount_charged(line),
              waived: waived?(line)
            }
          }
        end

        nil
      end

      def override_detected?(line, default)
        waived?(line) || amount_charged(line) != (default.effective_default_amount_cents || 0)
      end

      def amount_charged(line)
        (line[:amount_charged_cents] || line["amount_charged_cents"]).to_i
      end

      def waived?(line)
        !! (line[:waived] || line["waived"])
      end

      def transaction_type
        posting_params[:transaction_type].to_s.presence || "deposit"
      end
  end
end
