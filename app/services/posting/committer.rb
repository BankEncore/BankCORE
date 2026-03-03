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
        Posting::LedgerBalanceUpdater.call(legs: legs)

        cash_movement = Posting::Effects::CashMovementRecorder.new(
          request: request,
          legs: legs,
          teller_transaction: teller_transaction
        ).call

        Posting::Effects::PartyCashDailyTotalUpdater.call(cash_movement: cash_movement) if cash_movement.present?

        denom_set = persist_denomination_breakdown!(teller_transaction) if denomination_lines_from_metadata.any?

        create_transaction_posted_audit_event!(teller_transaction, posting_batch, denomination_set: denom_set)
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
          account_number = account_reference.to_s.sub(/\Aacct:/, "").strip.presence || account_reference
          account_id = Account.find_by(account_number: account_number)&.id

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

      def denomination_lines_from_metadata
        raw = request.fetch(:metadata, {})["denomination_lines"] || request.fetch(:metadata, {})[:denomination_lines]
        Array(raw).map { |l| l.to_h.symbolize_keys }
      end

      def persist_denomination_breakdown!(teller_transaction)
        raw = denomination_lines_from_metadata
        return nil if raw.blank?

        catalog = CashDenomination.enabled.to_a
        svc = DenominationBreakdownService.new
        lines = svc.parse_and_validate(raw, catalog)
        return nil if svc.errors.any? # validation failed; rely on WorkflowValidator to have caught

        svc.persist!(teller_transaction, lines)
      end

      def create_transaction_posted_audit_event!(teller_transaction, posting_batch, denomination_set: nil)
        metadata = posting_batch.metadata || {}
        audit_metadata = {
          "teller_transaction_id" => teller_transaction.id,
          "posting_batch_id" => posting_batch.id,
          "request_id" => request.fetch(:request_id).to_s
        }
        audit_metadata["served_party"] = metadata["served_party"] if metadata["served_party"].present?
        audit_metadata["primary_account_reference"] = metadata["primary_account_reference"].to_s if metadata["primary_account_reference"].present?
        audit_metadata["initiating_lookup"] = metadata["initiating_lookup"].to_s if metadata["initiating_lookup"].present?
        if denomination_set.present?
          audit_metadata["denomination_set_id"] = denomination_set.id
          audit_metadata["denomination_lines_count"] = denomination_set.denomination_lines.count
          audit_metadata["denomination_total_cents"] = denomination_set.total_cents
        end

        AuditEvent.create!(
          event_type: "transaction.posted",
          occurred_at: Time.current,
          actor_user_id: request.fetch(:user).id,
          branch_id: request.fetch(:branch).id,
          workstation_id: request.fetch(:workstation).id,
          teller_session_id: request.fetch(:teller_session).id,
          auditable: teller_transaction,
          metadata: audit_metadata
        )
      end
  end
end
