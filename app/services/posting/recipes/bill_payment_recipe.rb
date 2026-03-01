# frozen_string_literal: true

module Posting
  module Recipes
    class BillPaymentRecipe < BaseRecipe
      def normalized_entries
        explicit_entries = Array(posting_params[:entries]).map { |entry| entry.to_h.symbolize_keys }
        explicit_entries.present? ? explicit_entries : generated_entries
      end

      def posting_metadata
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
        check_total_cents = check_items.sum { |item| item[:amount_cents].to_i }
        payment_cents = posting_params[:payment_cents].to_i
        fee_cents = posting_params[:fee_cents].to_i
        total_cents = payment_cents + fee_cents
        bill_payment_cash_cents = posting_params[:bill_payment_cash_cents].to_i
        bill_payment_account_cents = posting_params[:bill_payment_account_cents].to_i

        payee = BillPayee.find_by(id: posting_params[:payee_id].to_s)
        metadata = {}
        metadata[:served_party] = served_party_metadata if served_party_metadata.any?
        metadata.merge!(related_records_metadata)
        metadata[:bill_payment] = {
          payee_id: posting_params[:payee_id].to_s,
          payee_code: payee&.code.to_s,
          payee_name: payee&.name.to_s,
          payee_reference: posting_params[:payee_reference].to_s,
          payment_cents: payment_cents,
          fee_cents: fee_cents,
          total_cents: total_cents,
          memo: posting_params[:memo].to_s,
          liability_account_reference: liability_account_reference,
          funding: {
            cash_cents: bill_payment_cash_cents,
            account_cents: bill_payment_account_cents,
            check_total_cents: check_total_cents
          }
        }
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
        payment_cents = posting_params[:payment_cents].to_i
        fee_cents = posting_params[:fee_cents].to_i
        total_due_cents = payment_cents + fee_cents
        primary_account_reference = posting_params[:primary_account_reference].to_s
        bill_payment_cash_cents = posting_params[:bill_payment_cash_cents].to_i
        bill_payment_account_cents = posting_params[:bill_payment_account_cents].to_i
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_total_cents = check_items.sum { |item| item[:amount_cents].to_i }
        liability_ref = liability_account_reference

        return [] unless payment_cents.positive?
        return [] if liability_ref.blank?

        total_payment_cents = bill_payment_cash_cents + bill_payment_account_cents + check_total_cents
        return [] unless total_payment_cents == total_due_cents

        entries = []

        if bill_payment_cash_cents.positive? && default_cash_account_reference.present?
          entries << { side: "debit", account_reference: default_cash_account_reference, amount_cents: bill_payment_cash_cents }
        end

        check_items.select { |item| item[:amount_cents].to_i.positive? }.each do |item|
          entries << { side: "debit", account_reference: item[:account_reference].to_s, amount_cents: item[:amount_cents].to_i }
        end

        primary_used = primary_account_reference.present? &&
          primary_account_reference != "0" &&
          primary_account_reference != "acct:0"
        if bill_payment_account_cents.positive? && primary_used
          entries << { side: "debit", account_reference: primary_account_reference, amount_cents: bill_payment_account_cents }
        end

        entries << { side: "credit", account_reference: liability_ref, amount_cents: payment_cents }
        entries << { side: "credit", account_reference: fee_income_account_reference, amount_cents: fee_cents } if fee_cents.positive?

        entries
      end

      def liability_account_reference
        ref = posting_params[:liability_account_reference].to_s.strip
        return ref if ref.present?

        payee_id = posting_params[:payee_id].to_s.presence
        return "" if payee_id.blank?

        payee = BillPayee.find_by(id: payee_id)
        payee&.liability_account_reference.to_s
      end

      def fee_income_account_reference
        posting_params[:fee_income_account_reference].to_s.presence || "income:bill_payment_fee"
      end
    end
  end
end
