# frozen_string_literal: true

module Posting
  module Parts
    module Flows
      class MiscReceiptFlow < BaseFlow
        def initialize(
          amount_cents:,
          misc_cash_cents:,
          misc_account_cents:,
          check_items:,
          primary_account_reference:,
          cash_account_reference:,
          income_account_reference:
        )
          @amount_cents = amount_cents.to_i
          @misc_cash_cents = misc_cash_cents.to_i
          @misc_account_cents = misc_account_cents.to_i
          @check_items = normalize_check_items(check_items)
          @primary_account_reference = primary_account_reference.to_s.strip
          @cash_account_reference = cash_account_reference.to_s.strip
          @income_account_reference = income_account_reference.to_s.strip
        end

        def validate!
          if amount_cents <= 0
            raise PartBuilder::ValidationError, "amount_cents must be positive, got #{amount_cents}"
          end

          if income_account_reference.blank?
            raise PartBuilder::ValidationError, "income_account_reference is required"
          end

          total_payment = misc_cash_cents + misc_account_cents + ck_total
          if total_payment != amount_cents
            raise PartBuilder::ValidationError,
              "Total payment (cash #{misc_cash_cents} + account #{misc_account_cents} + checks #{ck_total}) must equal amount_cents (#{amount_cents})"
          end

          if misc_cash_cents.negative? || misc_account_cents.negative?
            raise PartBuilder::ValidationError, "misc_cash_cents and misc_account_cents cannot be negative"
          end
        end

        def build_entries
          validate!
          enrich_legs(raw_legs)
        end

        private

        attr_reader :amount_cents, :misc_cash_cents, :misc_account_cents, :check_items,
          :primary_account_reference, :cash_account_reference, :income_account_reference

        def ck_total
          check_items.sum { |item| item[:amount_cents].to_i }
        end

        def raw_legs
          legs = []

          legs << { side: "debit", account_reference: cash_account_reference, amount_cents: misc_cash_cents } if misc_cash_cents.positive?

          check_items.each do |item|
            legs << {
              side: "debit",
              account_reference: item[:account_reference].to_s,
              amount_cents: item[:amount_cents].to_i
            }
          end

          primary_used = primary_account_reference.present? &&
            primary_account_reference != "0" &&
            primary_account_reference != "acct:0"
          legs << { side: "debit", account_reference: primary_account_reference, amount_cents: misc_account_cents } if misc_account_cents.positive? && primary_used

          legs << { side: "credit", account_reference: income_account_reference, amount_cents: amount_cents }
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
