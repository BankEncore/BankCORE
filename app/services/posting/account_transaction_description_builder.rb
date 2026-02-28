# frozen_string_literal: true

module Posting
  class AccountTransactionDescriptionBuilder
    CUSTOMER_PREFIXES = %w[acct:].freeze
    INTERNAL_PREFIXES = %w[cash: check: income: official_check: expense:].freeze

    def initialize(leg:, legs:, transaction_type:, metadata:, branch:)
      @leg = leg
      @legs = legs
      @transaction_type = transaction_type.to_s
      @metadata = metadata.to_h
      @branch = branch
    end

    def call
      return nil unless customer_account_leg?(leg)

      case transaction_type
      when "deposit" then deposit_description
      when "withdrawal" then withdrawal_description
      when "transfer" then transfer_description
      when "draft" then draft_description
      when "misc_receipt" then misc_receipt_description
      when "reversal" then reversal_description
      else
        nil
      end
    end

    def self.for_reversal(leg:, legs:, original_posting_batch:, branch:)
      original_desc = original_description_for_leg(leg, original_posting_batch)
      return nil if original_desc.blank?

      "Reversal of #{original_desc}"
    end

    private

    attr_reader :leg, :legs, :transaction_type, :metadata, :branch

    def account_reference
      leg.fetch(:account_reference).to_s
    end

    def direction
      leg.fetch(:side).to_s
    end

    def customer_account_leg?(leg)
      ref = leg.fetch(:account_reference).to_s
      return false if ref.blank?
      INTERNAL_PREFIXES.none? { |p| ref.start_with?(p) }
    end

    def deposit_description
      return nil unless direction == "credit"
      "Deposit at #{branch_code} - #{branch_name}"
    end

    def withdrawal_description
      return nil unless direction == "debit"
      "Withdrawal at #{branch_code} - #{branch_name}"
    end

    def transfer_description
      primary_ref = primary_account_reference
      counterparty_ref = counterparty_account_reference
      return nil if primary_ref.blank? || counterparty_ref.blank?

      if direction == "debit" && account_reference == primary_ref
        "Transfer to #{masked_account(extract_account_number(counterparty_ref))}"
      elsif direction == "credit" && account_reference == counterparty_ref
        "Transfer from #{masked_account(extract_account_number(primary_ref))}"
      else
        nil
      end
    end

    def draft_description
      return nil unless direction == "debit"
      draft_meta = metadata.dig("draft") || metadata.dig(:draft) || {}
      instrument = draft_meta["instrument_number"] || draft_meta[:instrument_number].to_s
      payee = draft_meta["payee_name"] || draft_meta[:payee_name].to_s
      return "Bank Draft" if instrument.blank? && payee.blank?
      "Bank Draft ##{instrument} - #{payee}".strip
    end

    def misc_receipt_description
      misc = metadata.dig("misc_receipt") || metadata.dig(:misc_receipt) || {}
      label = (misc["type_label"] || misc[:type_label]).to_s.strip
      label = "Misc Receipt" if label.blank?
      memo = (misc["memo"] || misc[:memo]).to_s.strip
      memo.present? ? "#{label} (#{memo})" : label
    end

    def reversal_description
      nil
    end

    def branch_code
      return "" if branch.blank?
      branch.respond_to?(:code) ? branch.code.to_s : ""
    end

    def branch_name
      return "" if branch.blank?
      branch.respond_to?(:name) ? branch.name.to_s : ""
    end

    def primary_account_reference
      debit_leg = legs.find { |l| l.fetch(:side).to_s == "debit" && customer_account_leg?(l) }
      debit_leg&.fetch(:account_reference)&.to_s
    end

    def counterparty_account_reference
      legs.find { |l| l.fetch(:side).to_s == "credit" && customer_account_leg?(l) }&.fetch(:account_reference)&.to_s
    end

    def extract_account_number(ref)
      ref.to_s.sub(/\Aacct:/, "").strip
    end

    def masked_account(account_number)
      return "xxxx" if account_number.blank?
      str = account_number.to_s.strip
      return "xxxx" if str.length < 4
      "xxxx" + str[-4, 4]
    end

    def self.original_description_for_leg(leg, original_posting_batch)
      account_ref = leg.fetch(:account_reference).to_s
      opposite_side = leg.fetch(:side).to_s == "debit" ? "credit" : "debit"

      original_at = original_posting_batch.account_transactions.find do |at|
        at.account_reference == account_ref && at.direction == opposite_side
      end
      original_at&.description
    end
  end
end
