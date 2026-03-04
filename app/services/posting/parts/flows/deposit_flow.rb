# frozen_string_literal: true

module Posting
  module Parts
    module Flows
      class DepositFlow < BaseFlow
        def initialize(amount_cents:, cash_back_cents:, fee_cents:, check_items:, primary_account_reference:, cash_account_reference:, fee_income_account_reference: nil)
          @amount_cents = amount_cents.to_i
          @cash_back_cents = cash_back_cents.to_i
          @fee_cents = fee_cents.to_i
          @check_items = normalize_check_items(check_items)
          @primary_account_reference = primary_account_reference.to_s.strip
          @cash_account_reference = cash_account_reference.to_s.strip
          @fee_income_account_reference = fee_income_account_reference.to_s.strip.presence || "income:deposit_fee"
        end

        def validate!
          total_received = amount_cents + ck_total
          if total_received <= 0
            raise PartBuilder::ValidationError, "Must have positive cash or checks received"
          end

          if cash_back_cents.negative?
            raise PartBuilder::ValidationError, "cash_back_cents cannot be negative, got #{cash_back_cents}"
          end

          if fee_cents.negative?
            raise PartBuilder::ValidationError, "fee_cents cannot be negative, got #{fee_cents}"
          end

          if cash_back_cents > total_received
            raise PartBuilder::ValidationError, "cash_back (#{cash_back_cents}) cannot exceed cash + checks received (#{total_received})"
          end

          if pac_total.negative?
            raise PartBuilder::ValidationError, "Net deposit (PAC) cannot be negative, got #{pac_total}"
          end
        end

        def build_entries
          validate!
          enrich_legs(raw_legs)
        end

        private

        attr_reader :amount_cents, :cash_back_cents, :fee_cents, :check_items,
          :primary_account_reference, :cash_account_reference, :fee_income_account_reference

        def ck_total
          check_items.sum { |item| item[:amount_cents].to_i }
        end

        def pac_total
          amount_cents + ck_total - cash_back_cents - fee_cents
        end

        def raw_legs
          legs = []

          legs << { side: "debit", account_reference: cash_account_reference, amount_cents: amount_cents } if amount_cents.positive?

          check_items.each do |item|
            legs << {
              side: "debit",
              account_reference: item[:account_reference].to_s,
              amount_cents: item[:amount_cents].to_i
            }
          end

          legs << { side: "credit", account_reference: cash_account_reference, amount_cents: cash_back_cents } if cash_back_cents.positive?
          legs << { side: "credit", account_reference: fee_income_account_reference, amount_cents: fee_cents } if fee_cents.positive?
          legs << { side: "credit", account_reference: primary_account_reference, amount_cents: pac_total } if pac_total.positive?

          legs
        end

        def enrich_legs(legs)
          check_index = 0
          legs.map.with_index do |leg, position|
            ref = leg[:account_reference].to_s
            metadata = if ref.start_with?("check:")
              item = check_items[check_index]
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

        def normalize_check_items(items)
          Array(items).map { |i| i.to_h.symbolize_keys }.select { |i| i[:amount_cents].to_i.positive? }
        end
      end
    end
  end
end
