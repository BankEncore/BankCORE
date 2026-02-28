module Posting
  class RecipeBuilder
    def initialize(posting_params:, default_cash_account_reference:)
      @posting_params = posting_params.to_h.symbolize_keys
      @default_cash_account_reference = default_cash_account_reference.to_s
    end

    def posting_metadata
      recipe.posting_metadata
    end

    def normalized_entries
      enrich_entries_with_structured_fields(recipe.normalized_entries)
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
        entries.map do |entry|
          metadata = check_metadata_for_entry(entry)
          parsed = AccountReferenceParser.parse(entry[:account_reference], metadata: metadata)
          entry.merge(
            reference_type: parsed[:reference_type],
            reference_identifier: parsed[:reference_identifier],
            check_routing_number: parsed[:check_routing_number],
            check_account_number: parsed[:check_account_number],
            check_number: parsed[:check_number],
            check_type: parsed[:check_type]
          )
        end
      end

      def check_metadata_for_entry(entry)
        ref = entry[:account_reference].to_s
        return {} unless ref.start_with?("check:")

        check_items = all_check_items_from_params
        item = check_items.find { |ci| (ci[:account_reference] || ci["account_reference"]).to_s == ref }
        return {} if item.blank?

        ct = (item[:check_type] || item["check_type"]).to_s.presence || "transit"
        { "check_type" => ct }
      end

      def all_check_items_from_params
        items = Array(posting_params[:check_items]).map { |i| i.to_h.symbolize_keys }
        return items if items.any?

        check_cashing = posting_params[:check_cashing] || posting_params["check_cashing"]
        Array(check_cashing&.dig("check_items") || check_cashing&.dig(:check_items)).map { |i| i.to_h.symbolize_keys }
      end
  end
end
