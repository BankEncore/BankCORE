# frozen_string_literal: true

module Posting
  module Parts
    module Flows
      class WithdrawalFlow < BaseFlow
        def initialize(amount_cents:, fee_cents:, primary_account_reference:, cash_account_reference:, fee_income_account_reference: nil)
          @amount_cents = amount_cents.to_i
          @fee_cents = fee_cents.to_i
          @primary_account_reference = primary_account_reference.to_s.strip
          @cash_account_reference = cash_account_reference.to_s.strip
          @fee_income_account_reference = fee_income_account_reference.to_s.strip.presence || "income:withdrawal_fee"
        end

        def validate!
          if amount_cents <= 0
            raise PartBuilder::ValidationError, "amount_cents must be positive, got #{amount_cents}"
          end

          if fee_cents.negative?
            raise PartBuilder::ValidationError, "fee_cents cannot be negative, got #{fee_cents}"
          end

          if fee_cents > amount_cents
            raise PartBuilder::ValidationError, "FEE (#{fee_cents}) exceeds PAD (#{amount_cents})"
          end
        end

        def build_entries
          validate!
          enrich_legs(raw_legs)
        end

        private

        attr_reader :amount_cents, :fee_cents, :primary_account_reference, :cash_account_reference, :fee_income_account_reference

        def co_total
          amount_cents - fee_cents
        end

        def raw_legs
          legs = [
            { side: "debit", account_reference: primary_account_reference, amount_cents: amount_cents },
            { side: "credit", account_reference: cash_account_reference, amount_cents: co_total }
          ]
          legs << { side: "credit", account_reference: fee_income_account_reference, amount_cents: fee_cents } if fee_cents.positive?
          legs
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
