module Posting
  module Recipes
    class DraftRecipe < BaseRecipe
      def normalized_entries
        explicit_entries = Array(posting_params[:entries]).map { |entry| entry.to_h.symbolize_keys }
        explicit_entries.present? ? explicit_entries : generated_entries
      end

      def posting_metadata
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
        metadata = {}
        metadata[:served_party] = served_party_metadata if served_party_metadata.any?
        metadata[:draft] = {
            draft_amount_cents: posting_params[:draft_amount_cents].to_i,
            fee_cents: posting_params[:draft_fee_cents].to_i,
            draft_cash_cents: posting_params[:draft_cash_cents].to_i,
            draft_account_cents: posting_params[:draft_account_cents].to_i,
            payee_name: posting_params[:draft_payee_name].to_s,
            instrument_number: posting_params[:draft_instrument_number].to_s,
            liability_account_reference: draft_liability_account_reference,
            fee_income_account_reference: draft_fee_income_account_reference
          }
        metadata.merge!(related_records_metadata)
        metadata[:check_items] = check_items.map do |item|
          {
            routing: item[:routing].to_s,
            account: item[:account].to_s,
            number: item[:number].to_s,
            account_reference: item[:account_reference].to_s,
            amount_cents: item[:amount_cents].to_i,
            check_type: item[:check_type].to_s.presence || "transit",
            hold_reason: item[:hold_reason].to_s,
            hold_until: item[:hold_until].to_s
          }
        end if check_items.any?
        metadata
      end

      private

      def generated_entries
        primary_account_reference = posting_params[:primary_account_reference].to_s
        draft_amount_cents = posting_params[:draft_amount_cents].to_i
        draft_fee_cents = posting_params[:draft_fee_cents].to_i
        draft_cash_cents = posting_params[:draft_cash_cents].to_i
        draft_account_cents = posting_params[:draft_account_cents].to_i
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        draft_check_cents = check_items.sum { |item| item[:amount_cents].to_i }
        liability_account_reference = draft_liability_account_reference

        return [] unless draft_amount_cents.positive?
        return [] if liability_account_reference.blank?

        total_due_cents = draft_amount_cents + draft_fee_cents
        total_payment_cents = draft_cash_cents + draft_account_cents + draft_check_cents
        return [] unless total_payment_cents == total_due_cents

        entries = []

        if draft_cash_cents.positive? && default_cash_account_reference.present?
          entries << { side: "debit", account_reference: default_cash_account_reference, amount_cents: draft_cash_cents }
        end

        check_items.select { |item| item[:amount_cents].to_i.positive? }.each do |item|
          entries << { side: "debit", account_reference: item[:account_reference].to_s, amount_cents: item[:amount_cents].to_i }
        end

        primary_used = primary_account_reference.present? &&
          primary_account_reference != "0" &&
          primary_account_reference != "acct:0"
        if draft_account_cents.positive? && primary_used
          entries << { side: "debit", account_reference: primary_account_reference, amount_cents: draft_account_cents }
        end

        entries << { side: "credit", account_reference: liability_account_reference, amount_cents: draft_amount_cents }

        if draft_fee_cents.positive?
          entries << { side: "credit", account_reference: draft_fee_income_account_reference, amount_cents: draft_fee_cents }
        end

        entries
      end

      def draft_liability_account_reference
        posting_params[:draft_liability_account_reference].presence || "official_check:outstanding"
      end

      def draft_fee_income_account_reference
        posting_params[:draft_fee_income_account_reference].presence || "income:draft_fee"
      end
    end
  end
end
