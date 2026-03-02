# frozen_string_literal: true

module Posting
  class LedgerBalanceUpdater
    def self.call(legs:)
      new(legs: legs).call
    end

    def initialize(legs:)
      @legs = legs
    end

    def call
      deltas = compute_deltas
      return if deltas.empty?

      account_numbers = deltas.keys.uniq
      Account.where(account_number: account_numbers).lock.each do |account|
        delta = deltas[account.account_number]
        next if delta.zero?

        account.increment!(:ledger_balance_cents, delta)
        account.update_column(:ledger_balance_updated_at, Time.current)
      end
    end

    private

    attr_reader :legs

    def compute_deltas
      legs.each_with_object(Hash.new(0)) do |leg, h|
        ref = leg.fetch(:account_reference).to_s.strip
        next unless customer_account_reference?(ref)

        account_number = normalize_customer_account_ref(ref)
        next if account_number.blank?

        delta = leg.fetch(:side) == "credit" ? leg.fetch(:amount_cents) : -leg.fetch(:amount_cents)
        h[account_number] += delta
      end
    end

    def customer_account_reference?(ref)
      return false if ref.blank?

      AccountReferenceParser::INTERNAL_PREFIXES.none? { |p| ref.start_with?(p) }
    end

    def normalize_customer_account_ref(ref)
      ref.to_s.sub(/\Aacct:/, "").strip.presence
    end
  end
end
