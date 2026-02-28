module Posting
  module Recipes
    class CheckCashingRecipe < BaseRecipe
      def normalized_entries
        explicit_entries = Array(posting_params[:entries]).map { |entry| entry.to_h.symbolize_keys }
        explicit_entries.present? ? explicit_entries : generated_entries
      end

      def posting_metadata
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
        check_amount_cents = check_items.sum { |item| item[:amount_cents].to_i }
        fee_cents = posting_params[:fee_cents].to_i
        net_cash_payout_cents = check_amount_cents - fee_cents

        {
          check_cashing: {
            check_items: check_items.map do |item|
              {
                routing: item[:routing].to_s,
                account: item[:account].to_s,
                number: item[:number].to_s,
                account_reference: item[:account_reference].to_s,
                amount_cents: item[:amount_cents].to_i
              }
            end,
            check_amount_cents: check_amount_cents,
            fee_cents: fee_cents,
            net_cash_payout_cents: net_cash_payout_cents,
            party_id: posting_params[:party_id].to_s,
            fee_income_account_reference: fee_income_account_reference,
            id_type: posting_params[:id_type].to_s,
            id_number: posting_params[:id_number].to_s
          }
        }
      end

      private

      def generated_entries
        amount_cents = posting_params[:amount_cents].to_i
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
        check_amount_cents = check_items.sum { |item| item[:amount_cents].to_i }
        fee_cents = posting_params[:fee_cents].to_i
        net_cash_payout_cents = check_amount_cents - fee_cents

        return [] if check_items.empty?
        return [] unless net_cash_payout_cents.positive?
        return [] unless amount_cents == net_cash_payout_cents

        entries = check_items.map do |item|
          { side: "debit", account_reference: item[:account_reference].to_s, amount_cents: item[:amount_cents].to_i }
        end
        entries << { side: "credit", account_reference: default_cash_account_reference, amount_cents: net_cash_payout_cents }
        entries << { side: "credit", account_reference: fee_income_account_reference, amount_cents: fee_cents } if fee_cents.positive?

        entries
      end

      def fee_income_account_reference
        posting_params[:fee_income_account_reference].presence || "income:check_cashing_fee"
      end
    end
  end
end
