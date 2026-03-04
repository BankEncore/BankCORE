module Posting
  class RecipeBuilder
    def initialize(posting_params:, default_cash_account_reference:)
      @posting_params = posting_params.to_h.symbolize_keys
      @default_cash_account_reference = default_cash_account_reference.to_s
    end

    def posting_metadata
      base = recipe.posting_metadata
      return base if misc_additions.blank?

      base.merge(misc_additions_metadata)
    end

    def normalized_entries
      entries = recipe.normalized_entries
      misc_legs = MiscAdditionLegBuilder.call(
        posting_params: posting_params,
        default_cash_account_reference: default_cash_account_reference,
        primary_account_reference: posting_params[:primary_account_reference].to_s
      )
      entries = entries + misc_legs if misc_legs.any?
      enrich_entries_with_structured_fields(entries)
    end

    private
      attr_reader :posting_params, :default_cash_account_reference

      def recipe
        @recipe ||= RecipeRegistry.for(posting_params[:transaction_type]).new(
          posting_params: posting_params,
          default_cash_account_reference: default_cash_account_reference
        )
      end

      def enrich_entries_with_structured_fields(entries)
        check_items = all_check_items_from_params
        check_index = 0

        entries.map do |entry|
          ref = entry[:account_reference].to_s
          metadata = if ref.start_with?("check:")
            item = check_items[check_index]
            check_index += 1
            item.present? ? { "check_type" => (item[:check_type] || item["check_type"]).to_s.presence || "transit" } : {}
          else
            {}
          end

          parsed = AccountReferenceParser.parse(entry[:account_reference], metadata: metadata)
          account_reference = canonicalize_account_reference(
            entry[:account_reference],
            parsed[:reference_type],
            parsed[:reference_identifier]
          )
          entry.merge(
            account_reference: account_reference,
            reference_type: parsed[:reference_type],
            reference_identifier: parsed[:reference_identifier],
            check_routing_number: parsed[:check_routing_number],
            check_account_number: parsed[:check_account_number],
            check_number: parsed[:check_number],
            check_type: parsed[:check_type]
          )
        end
      end

      def canonicalize_account_reference(raw, reference_type, reference_identifier)
        return raw.to_s if raw.blank?
        return raw.to_s if reference_type != "customer_account"
        return raw.to_s if reference_identifier.blank?

        return raw.to_s if raw.to_s.strip.start_with?("acct:")

        "acct:#{reference_identifier}"
      end

      def misc_additions
        raw = posting_params[:misc_additions] || posting_params["misc_additions"]
        Array(raw).map { |e| e.to_h.symbolize_keys }
      end

      def misc_additions_metadata
        return {} if misc_additions.blank?

        items = misc_additions.map do |line|
          type_id = (line[:misc_receipt_type_id] || line["misc_receipt_type_id"]).to_s.presence
          type = type_id.present? ? MiscReceiptType.find_by(id: type_id) : nil
          {
            misc_receipt_type_id: type_id&.to_i,
            type_label: type&.label.to_s,
            default_amount_cents: (line[:default_amount_cents] || line["default_amount_cents"]).to_i,
            amount_charged_cents: (line[:amount_charged_cents] || line["amount_charged_cents"]).to_i,
            waived: !! (line[:waived] || line["waived"])
          }
        end
        { misc_additions: items }
      end

      def all_check_items_from_params
        items = Array(posting_params[:check_items]).map { |i| i.to_h.symbolize_keys }
        return items if items.any?

        check_cashing = posting_params[:check_cashing] || posting_params["check_cashing"]
        Array(check_cashing&.dig("check_items") || check_cashing&.dig(:check_items)).map { |i| i.to_h.symbolize_keys }
      end
  end
end
