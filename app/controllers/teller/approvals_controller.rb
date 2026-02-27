module Teller
  class ApprovalsController < BaseController
    include PostingPrerequisites

    before_action :ensure_authorized
    before_action :require_posting_context!

    def create
      identifier, secret = resolve_credentials
      if identifier.blank? || secret.blank?
        render json: { ok: false, error: "Provide either email + password or teller number + PIN" }, status: :bad_request
        return
      end

      supervisor = Teller::CredentialVerifier.verify(identifier: identifier, secret: secret)
      policy_trigger = approval_params[:policy_trigger].presence || "amount_threshold"
      policy_context = parsed_policy_context

      if supervisor.blank?
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
          policy_trigger: policy_trigger,
          policy_context: policy_context,
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
          reason: approval_params[:reason].to_s,
          policy_trigger: policy_trigger,
          policy_context: policy_context
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
        params.permit(:request_id, :reason, :supervisor_email_address, :supervisor_password, :supervisor_teller_number, :supervisor_pin, :policy_trigger, :policy_context)
      end

      def resolve_credentials
        teller_number = approval_params[:supervisor_teller_number].to_s.strip
        pin = approval_params[:supervisor_pin].to_s
        if teller_number.present?
          [ teller_number, pin ]
        else
          email = approval_params[:supervisor_email_address].to_s.strip.downcase
          password = approval_params[:supervisor_password].to_s
          [ email.presence, password.presence ]
        end
      end

      def parsed_policy_context
        raw_context = approval_params[:policy_context]
        return {} if raw_context.blank?

        JSON.parse(raw_context)
      rescue JSON::ParserError
        {}
      end

      def approval_verifier
        @approval_verifier ||= ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base, serializer: JSON)
      end
  end
end
