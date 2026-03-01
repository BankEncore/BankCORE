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
        party_id = posting_params[:party_id].to_s.presence
        return {} if party_id.blank?

        party = Party.find_by(id: party_id)
        return { party_id: party_id } unless party

        pi = party.party_individual
        {
          party_id: party_id,
          id_type: (pi&.govt_id_type == "driver_license" ? "drivers_license" : pi&.govt_id_type).to_s.presence,
          id_number: pi&.govt_id.to_s.presence
        }.compact
      end

      def related_records_metadata
        h = {}
        il = posting_params[:initiating_lookup].to_s.strip.presence
        h[:initiating_lookup] = il if il.present?
        pr = posting_params[:primary_account_reference].to_s.strip.presence
        h[:primary_account_reference] = pr if pr.present?
        h
      end

      private

      attr_reader :posting_params, :default_cash_account_reference
    end
  end
end
