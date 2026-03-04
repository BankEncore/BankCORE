# frozen_string_literal: true

module Posting
  module Parts
    module Flows
      class DraftFlow < BaseFlow
        def initialize(
          draft_amount_cents:,
          draft_fee_cents:,
          draft_cash_cents:,
          draft_account_cents:,
          check_items:,
          primary_account_reference:,
          cash_account_reference:,
          draft_liability_account_reference:,
          draft_fee_income_account_reference: nil
        )
          @draft_amount_cents = draft_amount_cents.to_i
          @draft_fee_cents = draft_fee_cents.to_i
          @draft_cash_cents = draft_cash_cents.to_i
          @draft_account_cents = draft_account_cents.to_i
          @check_items = normalize_check_items(check_items)
          @primary_account_reference = primary_account_reference.to_s.strip
          @cash_account_reference = cash_account_reference.to_s.strip
          @draft_liability_account_reference = draft_liability_account_reference.to_s.strip
          @draft_fee_income_account_reference = draft_fee_income_account_reference.to_s.strip.presence || "income:draft_fee"
        end

        def validate!
          if draft_amount_cents <= 0
            raise PartBuilder::ValidationError, "draft_amount_cents must be positive, got #{draft_amount_cents}"
          end

          if draft_liability_account_reference.blank?
            raise PartBuilder::ValidationError, "draft_liability_account_reference is required"
          end

          total_due = draft_amount_cents + draft_fee_cents
          total_payment = draft_cash_cents + draft_account_cents + ck_total
          if total_payment != total_due
            raise PartBuilder::ValidationError,
              "Total payment (#{total_payment}) must equal total due (#{total_due})"
          end

          [ draft_cash_cents, draft_account_cents ].each do |amt|
            raise PartBuilder::ValidationError, "Funding amounts cannot be negative" if amt.negative?
          end
        end

        def build_entries
          validate!
          enrich_legs(raw_legs)
        end

        private

        attr_reader :draft_amount_cents, :draft_fee_cents, :draft_cash_cents, :draft_account_cents,
          :check_items, :primary_account_reference, :cash_account_reference,
          :draft_liability_account_reference, :draft_fee_income_account_reference

        def ck_total
          check_items.sum { |item| item[:amount_cents].to_i }
        end

        def raw_legs
          legs = []

          legs << { side: "debit", account_reference: cash_account_reference, amount_cents: draft_cash_cents } if draft_cash_cents.positive?

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
          legs << { side: "debit", account_reference: primary_account_reference, amount_cents: draft_account_cents } if draft_account_cents.positive? && primary_used

          legs << { side: "credit", account_reference: draft_liability_account_reference, amount_cents: draft_amount_cents }
          legs << { side: "credit", account_reference: draft_fee_income_account_reference, amount_cents: draft_fee_cents } if draft_fee_cents.positive?
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
