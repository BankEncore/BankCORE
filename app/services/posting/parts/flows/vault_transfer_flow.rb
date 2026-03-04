# frozen_string_literal: true

module Posting
  module Parts
    module Flows
      class VaultTransferFlow < BaseFlow
        def initialize(amount_cents:, source_cash_account_reference:, destination_cash_account_reference:)
          @amount_cents = amount_cents.to_i
          @source_cash_account_reference = source_cash_account_reference.to_s.strip
          @destination_cash_account_reference = destination_cash_account_reference.to_s.strip
        end

        def validate!
          if amount_cents <= 0
            raise PartBuilder::ValidationError, "amount_cents must be positive, got #{amount_cents}"
          end

          if source_cash_account_reference.blank?
            raise PartBuilder::ValidationError, "source_cash_account_reference is required"
          end

          if destination_cash_account_reference.blank?
            raise PartBuilder::ValidationError, "destination_cash_account_reference is required"
          end

          if source_cash_account_reference == destination_cash_account_reference
            raise PartBuilder::ValidationError, "Source and destination cannot be the same"
          end
        end

        def build_entries
          validate!
          enrich_legs(raw_legs)
        end

        private

        attr_reader :amount_cents, :source_cash_account_reference, :destination_cash_account_reference

        def raw_legs
          [
            { side: "debit", account_reference: destination_cash_account_reference, amount_cents: amount_cents },
            { side: "credit", account_reference: source_cash_account_reference, amount_cents: amount_cents }
          ]
        end

        def enrich_legs(legs)
          legs.map.with_index do |leg, position|
            parsed = AccountReferenceParser.parse(leg[:account_reference], metadata: {})
            leg.merge(
              position: position,
              account_reference: leg[:account_reference].to_s,
              reference_type: parsed[:reference_type],
              reference_identifier: parsed[:reference_identifier],
              check_routing_number: parsed[:check_routing_number],
              check_account_number: parsed[:check_account_number],
              check_number: parsed[:check_number],
              check_type: parsed[:check_type]
            )
          end
        end
      end
    end
  end
end
