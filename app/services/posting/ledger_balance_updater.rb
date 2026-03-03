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

      account_ids = deltas.keys.uniq
      Account.where(id: account_ids).lock.each do |account|
        delta = deltas[account.id]
        next if delta.zero?

        account.increment!(:ledger_balance_cents, delta)
        account.update_column(:ledger_balance_updated_at, Time.current)
      end
    end

    private

    attr_reader :legs

    def compute_deltas
      legs.each_with_object(Hash.new(0)) do |leg, h|
        reference = leg.fetch(:account_reference).to_s.strip
        next if reference.blank?

        resolved = LedgerReferences::Resolver.call(reference: reference)
        next unless resolved.ref_type == "customer_account"
        next if resolved.account_id.blank?

        delta = leg.fetch(:side) == "credit" ? leg.fetch(:amount_cents) : -leg.fetch(:amount_cents)
        h[resolved.account_id] += delta
      end
    end
  end
end
