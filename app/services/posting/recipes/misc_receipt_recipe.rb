# frozen_string_literal: true

module Posting
  module Recipes
    class MiscReceiptRecipe < BaseRecipe
      def normalized_entries
        explicit_entries = Array(posting_params[:entries]).map { |entry| entry.to_h.symbolize_keys }
        explicit_entries.present? ? explicit_entries : generated_entries
      end

      def posting_metadata
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_items = check_items.select { |item| item[:amount_cents].to_i.positive? }
        metadata = {}
        metadata[:served_party] = served_party_metadata if served_party_metadata.any?
        type_id = posting_params[:misc_receipt_type_id].to_s.presence
        type = MiscReceiptType.find_by(id: type_id) if type_id.present?
        metadata.merge!(related_records_metadata)
        metadata[:misc_receipt] = {
          misc_receipt_type_id: type_id,
          type_label: type&.label.to_s,
          unit_amount_cents: posting_params[:unit_amount_cents].to_i,
          quantity: [ posting_params[:quantity].to_i, 1 ].max,
          income_account_reference: income_account_reference,
          amount_cents: posting_params[:amount_cents].to_i,
          memo: posting_params[:memo].to_s,
          misc_cash_cents: posting_params[:misc_cash_cents].to_i,
          misc_account_cents: posting_params[:misc_account_cents].to_i,
          check_total_cents: check_items.sum { |item| item[:amount_cents].to_i }
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
        primary_account_reference = posting_params[:primary_account_reference].to_s
        amount_cents = posting_params[:amount_cents].to_i
        misc_cash_cents = posting_params[:misc_cash_cents].to_i
        misc_account_cents = posting_params[:misc_account_cents].to_i
        check_items = Array(posting_params[:check_items]).map { |item| item.to_h.symbolize_keys }
        check_total_cents = check_items.sum { |item| item[:amount_cents].to_i }
        income_ref = income_account_reference

        return [] unless amount_cents.positive?
        return [] if income_ref.blank?

        total_payment_cents = misc_cash_cents + misc_account_cents + check_total_cents
        return [] unless total_payment_cents == amount_cents

        entries = []

        if misc_cash_cents.positive? && default_cash_account_reference.present?
          entries << { side: "debit", account_reference: default_cash_account_reference, amount_cents: misc_cash_cents }
        end

        check_items.select { |item| item[:amount_cents].to_i.positive? }.each do |item|
          entries << { side: "debit", account_reference: item[:account_reference].to_s, amount_cents: item[:amount_cents].to_i }
        end

        primary_used = primary_account_reference.present? &&
          primary_account_reference != "0" &&
          primary_account_reference != "acct:0"
        if misc_account_cents.positive? && primary_used
          entries << { side: "debit", account_reference: primary_account_reference, amount_cents: misc_account_cents }
        end

        entries << { side: "credit", account_reference: income_ref, amount_cents: amount_cents }
      end

      def income_account_reference
        ref = posting_params[:income_account_reference].to_s.strip
        return ref if ref.present?

        type_id = posting_params[:misc_receipt_type_id].to_s.presence
        return "" if type_id.blank?

        type = MiscReceiptType.find_by(id: type_id)
        type&.income_account_reference.to_s
      end
    end
  end
end
