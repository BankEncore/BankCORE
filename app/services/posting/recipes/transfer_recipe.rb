module Posting
  module Recipes
    class TransferRecipe < BaseRecipe
      def normalized_entries
        explicit_entries = Array(posting_params[:entries]).map { |entry| entry.to_h.symbolize_keys }
        explicit_entries.present? ? explicit_entries : generated_entries
      end

      def posting_metadata
        metadata = {}
        metadata[:served_party] = served_party_metadata if served_party_metadata.any?
        fee_cents = posting_params[:fee_cents].to_i
        if fee_cents.positive?
          metadata[:fee_cents] = fee_cents
          metadata[:fee_income_account_reference] = transfer_fee_income_account_reference
        end
        metadata.merge!(related_records_metadata)
        metadata.presence || {}
      end

      private

      def generated_entries
        amount_cents = posting_params[:amount_cents].to_i
        primary_account_reference = posting_params[:primary_account_reference].to_s
        counterparty_account_reference = posting_params[:counterparty_account_reference].to_s
        fee_cents = posting_params[:fee_cents].to_i
        net_to_counterparty = [ amount_cents - fee_cents, 0 ].max

        entries = [
          { side: "debit", account_reference: primary_account_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: counterparty_account_reference, amount_cents: net_to_counterparty }
        ]
        entries << { side: "credit", account_reference: transfer_fee_income_account_reference, amount_cents: fee_cents } if fee_cents.positive?
        entries
      end

      def transfer_fee_income_account_reference
        posting_params[:fee_income_account_reference].presence || "income:transfer_fee"
      end
    end
  end
end
