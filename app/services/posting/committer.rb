module Posting
  class Committer
    def initialize(request:, legs:)
      @request = request
      @legs = legs
    end

    def call
      ActiveRecord::Base.transaction do
        teller_transaction = create_teller_transaction!
        posting_batch = create_posting_batch!(teller_transaction)
        persist_legs_and_account_transactions!(posting_batch, teller_transaction)

        Posting::Effects::CashMovementRecorder.new(
          request: request,
          legs: legs,
          teller_transaction: teller_transaction
        ).call

        posting_batch
      end
    end

    private
      attr_reader :request, :legs

      def create_teller_transaction!
        attrs = {
          user: request.fetch(:user),
          teller_session: request.fetch(:teller_session),
          branch: request.fetch(:branch),
          workstation: request.fetch(:workstation),
          request_id: request.fetch(:request_id),
          transaction_type: request.fetch(:transaction_type),
          currency: request.fetch(:currency),
          amount_cents: request.fetch(:amount_cents),
          status: "posted",
          posted_at: Time.current
        }
        attrs[:approved_by_user_id] = request[:approved_by_user_id] if request[:approved_by_user_id].present?
        TellerTransaction.create!(attrs)
      end

      def create_posting_batch!(teller_transaction)
        PostingBatch.create!(
          teller_transaction: teller_transaction,
          request_id: request.fetch(:request_id),
          currency: request.fetch(:currency),
          status: "committed",
          committed_at: Time.current,
          metadata: request.fetch(:metadata)
        )
      end

      def persist_legs_and_account_transactions!(posting_batch, teller_transaction)
        legs.each do |leg|
          account_reference = leg.fetch(:account_reference)
          account_id = Account.find_by(account_number: account_reference)&.id

          PostingLeg.create!(
            posting_batch: posting_batch,
            side: leg.fetch(:side),
            account_reference: account_reference,
            amount_cents: leg.fetch(:amount_cents),
            position: leg.fetch(:position)
          )

          description = Posting::AccountTransactionDescriptionBuilder.new(
            leg: leg,
            legs: legs,
            transaction_type: request.fetch(:transaction_type),
            metadata: request.fetch(:metadata),
            branch: request.fetch(:branch)
          ).call

          AccountTransaction.create!(
            teller_transaction: teller_transaction,
            posting_batch: posting_batch,
            account_reference: account_reference,
            account_id: account_id,
            direction: leg.fetch(:side),
            amount_cents: leg.fetch(:amount_cents),
            description: description
          )
        end
      end
  end
end
