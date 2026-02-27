class LocksController < ApplicationController
  layout "lock"

  def show
    unless session[:session_locked]
      redirect_to helpers.default_workspace_or_root_path
      return
    end
    @locked_at = session[:locked_at]
  end

  def create
    session[:session_locked] = true
    session[:locked_at] = Time.current
    session[:locked_by_user_id] = Current.user.id
    session[:return_to_after_unlock] = return_to_for_unlock
    session[:lock_trigger] = params[:trigger].presence || "manual"

    audit_lock(trigger: session[:lock_trigger])

    redirect_to lock_path
  end

  def update
    unless session[:session_locked]
      redirect_to lock_path
      return
    end

    identifier, secret = resolve_unlock_credentials
    if identifier.blank? || secret.blank?
      @locked_at = session[:locked_at]
      @error = "Provide either email + password or teller number + PIN"
      render :show, status: :unprocessable_entity
      return
    end

    user = Teller::CredentialVerifier.verify(identifier: identifier, secret: secret)
    if user.blank?
      audit_unlock_failed
      @locked_at = session[:locked_at]
      @error = "Invalid credentials"
      render :show, status: :unprocessable_entity
      return
    end

    unless can_unlock?(user)
      audit_unlock_failed
      @locked_at = session[:locked_at]
      @error = "You do not have permission to unlock this session"
      render :show, status: :forbidden
      return
    end

    return_to = session[:return_to_after_unlock]
    clear_lock
    audit_unlock_succeeded(user)

    redirect_to return_to.presence || helpers.default_workspace_or_root_path, notice: "Session unlocked."
  end

  def show
    unless session[:session_locked]
      redirect_to helpers.default_workspace_or_root_path
      return
    end
    @locked_at = to_time(session[:locked_at])
  end

  def to_time(value)
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
    return nil if value.blank?
    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  private
    def return_to_for_unlock
      request.referer.presence ||
        session[:teller_return_to].presence ||
        session[:csr_return_to].presence
    end

    def resolve_unlock_credentials
      teller_number = lock_params[:teller_number].to_s.strip
      pin = lock_params[:pin].to_s
      if teller_number.present?
        [ teller_number, pin ]
      else
        email = lock_params[:email_address].to_s.strip.downcase
        password = lock_params[:password].to_s
        [ email.presence, password.presence ]
      end
    end

    def can_unlock?(user)
      return true if user.id == session[:locked_by_user_id]
      user.has_permission?("approvals.override.execute", branch: current_branch, workstation: current_workstation)
    end

    def clear_lock
      session.delete(:session_locked)
      session.delete(:locked_at)
      session.delete(:locked_by_user_id)
      session.delete(:return_to_after_unlock)
      session.delete(:lock_trigger)
    end

    def lock_params
      params.permit(:teller_number, :pin, :email_address, :password)
    end

    def audit_lock(trigger:)
      workspace = workspace_from_referer(request.referer)
      AuditEvent.create!(
        event_type: "session.locked",
        actor_user_id: session[:locked_by_user_id],
        branch: current_branch,
        workstation: current_workstation,
        teller_session: current_teller_session,
        metadata: {
          user_id: session[:locked_by_user_id],
          locked_at: session[:locked_at].iso8601,
          trigger: trigger,
          workspace: workspace
        }.to_json,
        occurred_at: Time.current
      )
    end

    def workspace_from_referer(referer)
      return "root" if referer.blank?
      return "teller" if referer.include?("/teller")
      return "csr" if referer.include?("/csr")
      return "ops" if referer.include?("/ops")
      return "admin" if referer.include?("/admin")
      "root"
    end

    def audit_unlock_succeeded(user)
      AuditEvent.create!(
        event_type: "session.unlock_succeeded",
        actor_user: user,
        branch: current_branch,
        workstation: current_workstation,
        teller_session: current_teller_session,
        metadata: {
          unlocked_by_user_id: user.id,
          unlocked_at: Time.current.iso8601
        }.to_json,
        occurred_at: Time.current
      )
    end

    def audit_unlock_failed
      AuditEvent.create!(
        event_type: "session.unlock_failed",
        actor_user_id: nil,
        branch: current_branch,
        workstation: current_workstation,
        teller_session: current_teller_session,
        metadata: {}.to_json,
        occurred_at: Time.current
      )
    end
end
