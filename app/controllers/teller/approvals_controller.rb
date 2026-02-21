module Teller
  class ApprovalsController < ApplicationController
    include PostingPrerequisites

    before_action :ensure_authorized
    before_action :require_posting_context!

    def create
      supervisor = User.find_by(email_address: approval_params[:supervisor_email_address].to_s.strip.downcase)

      if supervisor.blank? || !supervisor.authenticate(approval_params[:supervisor_password].to_s)
        render json: { ok: false, error: "Invalid supervisor credentials" }, status: :unauthorized
        return
      end

      unless supervisor.has_permission?("approvals.override.execute", branch: current_branch, workstation: current_workstation)
        render json: { ok: false, error: "Supervisor does not have override permission" }, status: :forbidden
        return
      end

      token = approval_verifier.generate(
        {
          supervisor_user_id: supervisor.id,
          request_id: approval_params[:request_id].to_s,
          reason: approval_params[:reason].to_s,
          approved_at: Time.current.to_i
        },
        expires_in: 10.minutes
      )

      AuditEvent.create!(
        event_type: "approval.override.granted",
        actor_user: supervisor,
        branch: current_branch,
        workstation: current_workstation,
        teller_session: current_teller_session,
        metadata: {
          request_id: approval_params[:request_id].to_s,
          requester_user_id: Current.user&.id,
          reason: approval_params[:reason].to_s
        }.to_json,
        occurred_at: Time.current
      )

      render json: { ok: true, approval_token: token }
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end

      def approval_params
        params.permit(:request_id, :reason, :supervisor_email_address, :supervisor_password)
      end

      def approval_verifier
        @approval_verifier ||= ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base, serializer: JSON)
      end
  end
end
