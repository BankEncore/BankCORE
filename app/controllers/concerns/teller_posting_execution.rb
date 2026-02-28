module TellerPostingExecution
  extend ActiveSupport::Concern

  include PostingRequestBuilder

  private
    def execute_posting(forced_transaction_type: nil)
      request_params = posting_params.to_h.symbolize_keys
      request_params[:transaction_type] = forced_transaction_type if forced_transaction_type.present?
      request_params[:request_id] = request_params[:request_id].presence || "server-#{Time.current.to_i}-#{SecureRandom.hex(4)}"

      validation_errors = Posting::WorkflowValidator.errors(request_params, mode: :post)
      if validation_errors.present?
        render json: { ok: false, error: validation_errors.first }, status: :unprocessable_entity
        return
      end

      advisory_check = AdvisoryService.check_posting_allowed(
        primary_account_reference: request_params[:primary_account_reference],
        party_id: request_params[:party_id],
        acknowledged_advisory_ids: params[:acknowledged_advisory_ids]
      )
      unless advisory_check[:allowed]
        status = advisory_check[:status] || :unprocessable_entity
        error = advisory_check[:error] || "Posting not allowed"
        error += ": #{advisory_check[:advisory]&.title}" if advisory_check[:advisory]&.title.present?
        render json: { ok: false, error: error }, status: status
        return
      end

      approved_by_user_id = nil
      if approval_required?(request_params)
        token = request_params[:approval_token].to_s
        if token.blank?
          render json: { ok: false, error: "Supervisor approval is required for this amount" }, status: :unprocessable_entity
          return
        end

        begin
          payload = approval_verifier.verify(token)
          if payload["request_id"].to_s != request_params[:request_id].to_s
            render json: { ok: false, error: "Approval token does not match request" }, status: :unprocessable_entity
            return
          end
          approved_by_user_id = payload["supervisor_user_id"]
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          render json: { ok: false, error: "Approval token is invalid or expired" }, status: :unprocessable_entity
          return
        end
      end

      posting_batch = Posting::Engine.new(
        user: Current.user,
        teller_session: current_teller_session,
        branch: current_branch,
        workstation: current_workstation,
        request_id: request_params[:request_id],
        transaction_type: request_params[:transaction_type],
        amount_cents: request_params[:amount_cents],
        entries: normalized_entries(request_params),
        metadata: posting_metadata(request_params),
        currency: request_params[:currency].presence || "USD",
        approved_by_user_id: approved_by_user_id
      ).call

      render json: {
        ok: true,
        posting_batch_id: posting_batch.id,
        teller_transaction_id: posting_batch.teller_transaction_id,
        request_id: request_params[:request_id]
      }
    rescue Posting::Engine::Error, ActiveRecord::RecordInvalid => error
      render json: { ok: false, error: error.message }, status: :unprocessable_entity
    end

    def posting_params
      params.permit(
        :authenticity_token,
        :request_id,
        :transaction_type,
        :amount_cents,
        :cash_back_cents,
        :currency,
        :approval_token,
        :primary_account_reference,
        :counterparty_account_reference,
        :cash_account_reference,
        :vault_transfer_direction,
        :vault_transfer_source_cash_account_reference,
        :vault_transfer_destination_cash_account_reference,
        :vault_transfer_from_reference,
        :vault_transfer_to_reference,
        :vault_transfer_reason_code,
        :vault_transfer_memo,
        :fee_cents,
        :fee_income_account_reference,
        :party_id,
        :id_type,
        :id_number,
        :draft_amount_cents,
        :draft_fee_cents,
        :draft_cash_cents,
        :draft_account_cents,
        :draft_payee_name,
        :draft_instrument_number,
        :draft_liability_account_reference,
        :draft_fee_income_account_reference,
        acknowledged_advisory_ids: [],
        check_items: [ :routing, :account, :number, :account_reference, :amount_cents, :check_type, :hold_reason, :hold_until ],
        entries: [ :side, :account_reference, :amount_cents ]
      )
    end

    def approval_verifier
      @approval_verifier ||= ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base, serializer: JSON)
    end
end
