module Posting
  class ReversalService
    class Error < StandardError; end

    def initialize(
      user:,
      teller_session:,
      branch:,
      workstation:,
      original_teller_transaction_id:,
      reversal_reason_code:,
      reversal_memo:,
      request_id:,
      approved_by_user_id: nil
    )
      @user = user
      @teller_session = teller_session
      @branch = branch
      @workstation = workstation
      @original_teller_transaction_id = original_teller_transaction_id
      @reversal_reason_code = reversal_reason_code
      @reversal_memo = reversal_memo
      @request_id = request_id.to_s
      @approved_by_user_id = approved_by_user_id
    end

    def call
      existing_batch = PostingBatch.find_by(request_id: request_id)
      return existing_batch if existing_batch.present?

      original = TellerTransaction.find_by(id: original_teller_transaction_id)
      raise Error, "Original transaction not found" if original.blank?

      legs = ReversalRecipeBuilder.new(original_teller_transaction: original).entries
      Posting::BalanceChecker.call(legs: legs, error_class: Error)

      request = build_request(original: original, legs: legs)
      Posting::PolicyChecker.call(request: request, error_class: Error)

      ActiveRecord::Base.transaction do
        reversal_transaction = create_reversal_transaction!(original)
        reversal_batch = create_reversal_batch!(reversal_transaction, original)
        persist_legs_and_account_transactions!(reversal_batch, reversal_transaction, legs)
        Posting::Effects::CashMovementRecorder.new(
          request: request,
          legs: legs,
          teller_transaction: reversal_transaction
        ).call
        original.update!(
          reversed_by_teller_transaction_id: reversal_transaction.id,
          reversed_at: Time.current
        )
        reversal_batch
      end
    rescue ActiveRecord::RecordNotUnique
      PostingBatch.find_by!(request_id: request_id)
    end

    private
      attr_reader :user, :teller_session, :branch, :workstation,
        :original_teller_transaction_id, :reversal_reason_code, :reversal_memo, :request_id,
        :approved_by_user_id

      def build_request(original:, legs:)
        {
          user: user,
          teller_session: teller_session,
          branch: branch,
          workstation: workstation,
          request_id: request_id,
          transaction_type: "reversal",
          amount_cents: original.amount_cents,
          currency: original.currency,
          metadata: {
            reversal: {
              original_teller_transaction_id: original.id,
              original_request_id: original.request_id,
              original_transaction_type: original.transaction_type,
              reason_code: reversal_reason_code,
              memo: reversal_memo,
              approved_by_user_id: approved_by_user_id
            }
          },
          entries: legs
        }
      end

      def create_reversal_transaction!(original)
        TellerTransaction.create!(
          user: user,
          teller_session: teller_session,
          branch: branch,
          workstation: workstation,
          request_id: request_id,
          transaction_type: "reversal",
          currency: original.currency,
          amount_cents: original.amount_cents,
          status: "posted",
          posted_at: Time.current,
          reversal_of_teller_transaction_id: original.id,
          reversal_reason_code: reversal_reason_code,
          reversal_memo: reversal_memo,
          approved_by_user_id: approved_by_user_id
        )
      end

      def create_reversal_batch!(reversal_transaction, original)
        PostingBatch.create!(
          teller_transaction: reversal_transaction,
          request_id: request_id,
          currency: original.currency,
          status: "committed",
          committed_at: Time.current,
          metadata: {
            reversal: {
              original_teller_transaction_id: original.id,
              original_request_id: original.request_id,
              original_transaction_type: original.transaction_type,
              reason_code: reversal_reason_code,
              memo: reversal_memo,
              approved_by_user_id: approved_by_user_id
            }
          },
          reversal_of_posting_batch_id: original.posting_batch.id
        )
      end

      def persist_legs_and_account_transactions!(posting_batch, teller_transaction, legs)
        original_batch = if posting_batch.reversal_of_posting_batch_id.present?
          PostingBatch.includes(:account_transactions).find_by(id: posting_batch.reversal_of_posting_batch_id)
        else
          teller_transaction.reversal_of_teller_transaction&.posting_batch
        end

        legs.each do |leg|
          account_reference = leg.fetch(:account_reference)
          account_id = Account.find_by(account_number: account_reference)&.id

          PostingLeg.create!(
            posting_batch: posting_batch,
            side: leg.fetch(:side),
            account_reference: account_reference,
            amount_cents: leg.fetch(:amount_cents),
            position: leg.fetch(:position),
            reference_type: leg[:reference_type],
            reference_identifier: leg[:reference_identifier],
            check_routing_number: leg[:check_routing_number],
            check_account_number: leg[:check_account_number],
            check_number: leg[:check_number],
            check_type: leg[:check_type]
          )

          description = if original_batch.present?
            original_desc = Posting::AccountTransactionDescriptionBuilder.original_description_for_leg(leg, original_batch)
            original_desc.present? ? "Reversal of #{original_desc}" : nil
          end

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
