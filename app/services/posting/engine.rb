module Posting
  class Engine
    class Error < StandardError; end

    attr_reader :request

    def initialize(user:, teller_session:, branch:, workstation:, request_id:, transaction_type:, amount_cents:, entries:, metadata: {}, currency: "USD", approved_by_user_id: nil)
      @request = build_request(
        user: user,
        teller_session: teller_session,
        branch: branch,
        workstation: workstation,
        request_id: request_id,
        transaction_type: transaction_type,
        amount_cents: amount_cents,
        entries: entries,
        metadata: metadata,
        currency: currency,
        approved_by_user_id: approved_by_user_id
      )
    end

    def call
      existing_batch = PostingBatch.find_by(request_id: request.fetch(:request_id))
      return existing_batch if existing_batch.present?

      validate_request
      apply_policy
      legs = generate_legs
      validate_balance(legs)
      commit(legs)
    rescue ActiveRecord::RecordNotUnique
      PostingBatch.find_by!(request_id: request.fetch(:request_id))
    end

    private
      def build_request(user:, teller_session:, branch:, workstation:, request_id:, transaction_type:, amount_cents:, entries:, metadata:, currency:, approved_by_user_id: nil)
        {
          user: user,
          teller_session: teller_session,
          branch: branch,
          workstation: workstation,
          request_id: request_id.to_s,
          transaction_type: transaction_type.to_s,
          amount_cents: amount_cents.to_i,
          metadata: metadata.presence || {},
          currency: currency.to_s,
          approved_by_user_id: approved_by_user_id,
          entries: Array(entries).map.with_index do |entry, index|
            base = {
              side: entry.fetch(:side).to_s,
              account_reference: entry.fetch(:account_reference).to_s,
              amount_cents: entry.fetch(:amount_cents).to_i,
              position: index
            }
            base[:reference_type] = entry[:reference_type] if entry[:reference_type].present?
            base[:reference_identifier] = entry[:reference_identifier] if entry[:reference_identifier].present?
            base[:check_routing_number] = entry[:check_routing_number] if entry[:check_routing_number].present?
            base[:check_account_number] = entry[:check_account_number] if entry[:check_account_number].present?
            base[:check_number] = entry[:check_number] if entry[:check_number].present?
            base[:check_type] = entry[:check_type] if entry[:check_type].present?
            base
          end
        }
      end

      def validate_request
        Posting::RequestValidator.call(request: request, error_class: Error)
      end

      def apply_policy
        Posting::PolicyChecker.call(request: request, error_class: Error)
      end

      def generate_legs
        request.fetch(:entries)
      end

      def validate_balance(legs)
        Posting::BalanceChecker.call(legs: legs, error_class: Error)
      end

      def commit(legs)
        Posting::Committer.new(request: request, legs: legs).call
      end
  end
end
