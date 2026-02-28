# frozen_string_literal: true

module Posting
  class ReferenceLabelMapper
    INCOME_LABELS = {
      "check_cashing_fee" => "Check cashing fee",
      "transfer_fee" => "Transfer fee",
      "draft_fee" => "Draft fee",
      "cash_over" => "Cash over",
      "cash_short" => "Cash short",
      "variance" => "Variance"
    }.freeze

    def self.label_for(leg_or_hash, branch: nil)
      new(leg_or_hash, branch: branch).label
    end

    def initialize(leg_or_hash, branch: nil)
      @leg_or_hash = leg_or_hash
      @branch = branch
    end

    def label
      type = extract(:reference_type)
      identifier = extract(:reference_identifier)
      account_ref = extract_account_reference

      if type.blank?
        return account_ref.presence || "—"
      end

      case type
      when "income" then income_label(identifier)
      when "cash_location" then cash_location_label(identifier)
      when "customer_account" then customer_account_label(identifier)
      when "check_clearing" then check_clearing_label(identifier)
      when "liability" then liability_label(identifier)
      when "expense" then expense_label(identifier)
      else
        humanize_identifier(identifier).presence || account_ref.presence || "—"
      end
    end

    private

    attr_reader :leg_or_hash, :branch

    def extract(key)
      if leg_or_hash.is_a?(Hash)
        leg_or_hash[key] || leg_or_hash[key.to_s]
      elsif leg_or_hash.respond_to?(key)
        leg_or_hash.public_send(key)
      end
    end

    def extract_account_reference
      if leg_or_hash.is_a?(Hash)
        leg_or_hash[:account_reference] || leg_or_hash["account_reference"]
      elsif leg_or_hash.respond_to?(:account_reference)
        leg_or_hash.account_reference
      end
    end

    def income_label(identifier)
      INCOME_LABELS[identifier.to_s] || humanize_identifier(identifier)
    end

    def cash_location_label(identifier)
      return "—" if identifier.blank?

      if branch.present?
        loc = CashLocation.find_by(branch_id: branch.id, code: identifier)
        loc ? "#{loc.location_type.titleize} #{loc.name}" : "#{identifier} (unresolved)"
      else
        identifier
      end
    end

    def customer_account_label(identifier)
      return "—" if identifier.blank?
      str = identifier.to_s.strip
      masked = str.length >= 4 ? "xxxx#{str[-4, 4]}" : "xxxx"
      "Account #{masked}"
    end

    def check_clearing_label(identifier)
      check_type = extract(:check_type).to_s.presence
      suffix = case check_type
      when "transit" then " (transit)"
      when "on_us" then " (on us)"
      when "bank_draft" then " (bank draft)"
      else ""
      end
      "Check#{suffix}"
    end

    def liability_label(identifier)
      humanize_identifier(identifier).presence || "Liability"
    end

    def expense_label(identifier)
      humanize_identifier(identifier).presence || "Expense"
    end

    def humanize_identifier(identifier)
      return "" if identifier.blank?
      identifier.to_s.tr("_", " ").humanize
    end
  end
end
