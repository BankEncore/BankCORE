module Posting
  module Recipes
    class BaseRecipe
      def initialize(posting_params:, default_cash_account_reference:)
        @posting_params = posting_params.to_h.symbolize_keys
        @default_cash_account_reference = default_cash_account_reference.to_s
      end

      def normalized_entries
        raise NotImplementedError, "#{self.class}#normalized_entries must be implemented"
      end

      def posting_metadata
        {}
      end

      def served_party_metadata
        {
          party_id: posting_params[:party_id].to_s.presence,
          id_type: posting_params[:id_type].to_s.presence,
          id_number: posting_params[:id_number].to_s.presence
        }.compact
      end

      private

      attr_reader :posting_params, :default_cash_account_reference
    end
  end
end
