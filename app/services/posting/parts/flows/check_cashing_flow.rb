# frozen_string_literal: true

module Posting
  module Parts
    module Flows
      class CheckCashingFlow < BaseFlow
        def initialize(transaction_parts:)
          @parts = transaction_parts
        end

        def validate!
          if parts.check_items.empty?
            raise PartBuilder::ValidationError, "check_items cannot be empty"
          end

          if parts.fee_total > parts.ck_total
            raise PartBuilder::ValidationError, "FEE (#{parts.fee_total}) exceeds CK (#{parts.ck_total})"
          end

          if parts.co_total <= 0
            raise PartBuilder::ValidationError, "Disbursement (CK - FEE) must be positive, got #{parts.co_total}"
          end

          unless parts.ck_total == parts.co_total + parts.fee_total
            raise PartBuilder::ValidationError, "Equation CK = CO + FEE not satisfied: #{parts.ck_total} != #{parts.co_total} + #{parts.fee_total}"
          end
        end

        def build_entries
          validate!
          enrich_legs(raw_legs)
        end

        private

        attr_reader :parts

        def raw_legs
          legs = []
          parts.check_items.each do |item|
            legs << {
              side: "debit",
              account_reference: item[:account_reference].to_s,
              amount_cents: item[:amount_cents].to_i
            }
          end
          legs << { side: "credit", account_reference: parts.cash_account_reference, amount_cents: parts.co_total }
          legs << { side: "credit", account_reference: parts.fee_income_account_reference, amount_cents: parts.fee_total } if parts.fee_total.positive?
          legs
        end

        def enrich_legs(legs)
          check_index = 0
          legs.map.with_index do |leg, position|
            ref = leg[:account_reference].to_s
            metadata = if ref.start_with?("check:")
              item = parts.check_items[check_index]
              check_index += 1
              item ? { "check_type" => (item[:check_type] || item["check_type"]).to_s.presence || "transit" } : {}
            else
              {}
            end

            parsed = AccountReferenceParser.parse(leg[:account_reference], metadata: metadata)
            leg.merge(
              position: position,
              account_reference: ref,
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
