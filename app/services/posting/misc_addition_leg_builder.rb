# frozen_string_literal: true

module Posting
  class MiscAdditionLegBuilder
    FEE_DEBIT_FROM_CASH_TYPES = %w[deposit withdrawal draft misc_receipt bill_payment].freeze
    FEE_DEBIT_FROM_ACCOUNT_TYPES = %w[transfer check_cashing].freeze

    def self.call(posting_params:, default_cash_account_reference:, primary_account_reference:)
      new(
        posting_params: posting_params,
        default_cash_account_reference: default_cash_account_reference,
        primary_account_reference: primary_account_reference
      ).call
    end

    def initialize(posting_params:, default_cash_account_reference:, primary_account_reference:)
      @posting_params = posting_params.to_h.symbolize_keys
      @default_cash_account_reference = default_cash_account_reference.to_s
      @primary_account_reference = primary_account_reference.to_s
    end

    def call
      misc_additions.filter_map { |line| build_legs_for_line(line) }.flatten(1)
    end

    private
      attr_reader :posting_params, :default_cash_account_reference, :primary_account_reference

      def misc_additions
        raw = posting_params[:misc_additions] || posting_params["misc_additions"]
        Array(raw).map { |e| e.to_h.symbolize_keys }
      end

      def build_legs_for_line(line)
        return [] if waived?(line)

        amount = (line[:amount_charged_cents] || line["amount_charged_cents"]).to_i
        return [] if amount <= 0

        type_id = (line[:misc_receipt_type_id] || line["misc_receipt_type_id"]).to_s.presence
        return [] if type_id.blank?

        type = MiscReceiptType.find_by(id: type_id)
        return [] unless type&.income_account_reference.present?

        debit_ref = fee_debit_account_reference
        return [] if debit_ref.blank?

        [
          { side: "debit", account_reference: debit_ref, amount_cents: amount },
          { side: "credit", account_reference: type.income_account_reference, amount_cents: amount }
        ]
      end

      def waived?(line)
        !! (line[:waived] || line["waived"])
      end

      def fee_debit_account_reference
        transaction_type = posting_params[:transaction_type].to_s.presence || "deposit"

        if FEE_DEBIT_FROM_ACCOUNT_TYPES.include?(transaction_type)
          primary_account_reference.presence
        elsif transaction_type == "draft"
          draft_cash_cents = posting_params[:draft_cash_cents].to_i
          draft_account_cents = posting_params[:draft_account_cents].to_i
          if draft_account_cents.positive? && draft_cash_cents.zero?
            primary_account_reference.presence
          else
            default_cash_account_reference.presence
          end
        elsif FEE_DEBIT_FROM_CASH_TYPES.include?(transaction_type)
          default_cash_account_reference.presence
        else
          default_cash_account_reference.presence || primary_account_reference.presence
        end
      end
  end
end
