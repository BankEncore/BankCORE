module Teller
  class ReversalsController < BaseController
    include PostingPrerequisites

    before_action :load_original_transaction
    before_action :ensure_reversible
    before_action :ensure_authorized
    before_action :require_posting_context!, only: [ :create ]

    def new
      @reversal_reason_codes = reversal_reason_codes
    end

    def create
      payload = verify_approval_token!
      batch = Posting::ReversalService.new(
        user: Current.user,
        teller_session: current_teller_session,
        branch: current_branch,
        workstation: current_workstation,
        original_teller_transaction_id: @original_transaction.id,
        reversal_reason_code: params[:reversal_reason_code].to_s.strip,
        reversal_memo: params[:reversal_memo].to_s.strip,
        request_id: params[:request_id].presence || "reversal-#{@original_transaction.id}-#{Time.current.to_i}-#{SecureRandom.hex(4)}",
        approved_by_user_id: payload["supervisor_user_id"]
      ).call

      redirect_to teller_receipt_path(request_id: batch.request_id),
        notice: "Reversal posted successfully."
    rescue Posting::ReversalService::Error, Posting::ReversalRecipeBuilder::Error => e
      @reversal_reason_codes = reversal_reason_codes
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      @reversal_reason_codes = reversal_reason_codes
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    private
      def load_original_transaction
        @original_transaction = TellerTransaction.find_by(id: params[:id])
        return if @original_transaction.present?

        redirect_to teller_root_path, alert: "Transaction not found."
      end

      def ensure_reversible
        return if @original_transaction&.reversible?

        redirect_to teller_root_path, alert: "This transaction cannot be reversed."
      end

      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end

      def verify_approval_token!
        token = params[:approval_token].to_s
        raise Posting::ReversalService::Error, "Supervisor approval is required" if token.blank?

        payload = approval_verifier.verify(token)
        if payload["policy_trigger"].to_s != "transaction_reversal"
          raise Posting::ReversalService::Error, "Invalid approval token for reversal"
        end
        payload
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        raise Posting::ReversalService::Error, "Approval token is invalid or expired"
      end

      def approval_verifier
        @approval_verifier ||= ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base, serializer: JSON)
      end

      def reversal_reason_codes
        [
          [ "Entry error", "ENTRY_ERROR" ],
          [ "Duplicate transaction", "DUPLICATE" ],
          [ "Customer request", "CUSTOMER_REQUEST" ],
          [ "Wrong account", "WRONG_ACCOUNT" ],
          [ "Wrong amount", "WRONG_AMOUNT" ],
          [ "Other", "OTHER" ]
        ]
      end
  end
end
