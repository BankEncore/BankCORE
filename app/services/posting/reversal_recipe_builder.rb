module Posting
  class ReversalRecipeBuilder
    class Error < StandardError; end

    def initialize(original_teller_transaction:)
      @original_teller_transaction = original_teller_transaction
    end

    def entries
      validate_original!
      original_batch.posting_legs.order(:position).map.with_index do |leg, index|
        {
          side: inverted_side(leg.side),
          account_reference: leg.account_reference,
          amount_cents: leg.amount_cents,
          position: index,
          reference_type: leg.reference_type,
          reference_identifier: leg.reference_identifier,
          check_routing_number: leg.check_routing_number,
          check_account_number: leg.check_account_number,
          check_number: leg.check_number,
          check_type: leg.check_type
        }
      end
    end

    private
      attr_reader :original_teller_transaction

      def original_batch
        @original_batch ||= original_teller_transaction.posting_batch
      end

      def validate_original!
        raise Error, "Original transaction is not reversible" unless original_teller_transaction.reversible?
        raise Error, "Original transaction has no posting batch" if original_batch.blank?
        raise Error, "Original transaction is not posted" unless original_teller_transaction.status == "posted"
      end

      def inverted_side(side)
        side == "debit" ? "credit" : "debit"
      end
  end
end
