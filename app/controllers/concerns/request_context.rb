module RequestContext
  extend ActiveSupport::Concern

  BRANCH_COOKIE_KEY = :current_branch_id
  WORKSTATION_COOKIE_KEY = :current_workstation_id

  included do
    before_action :set_request_context
    helper_method :current_branch, :current_workstation, :current_teller_session
  end

  private
    def teller_context_complete?
      current_branch.present? && current_workstation.present?
    end

    def set_request_context
      Current.branch = current_branch
      Current.workstation = current_workstation
      Current.teller_session = current_teller_session
    end

    def current_branch
      return @current_branch if defined?(@current_branch)

      selected_branch_id = selected_branch_id_from_request
      @current_branch = Branch.find_by(id: selected_branch_id)
      session[:current_branch_id] = @current_branch&.id
      persist_context_cookie(BRANCH_COOKIE_KEY, @current_branch&.id)
      @current_branch
    end

    def current_workstation
      return @current_workstation if defined?(@current_workstation)

      selected_workstation_id = selected_workstation_id_from_request
      workstation = Workstation.find_by(id: selected_workstation_id)

      if workstation.present? && current_branch.present? && workstation.branch_id != current_branch.id
        workstation = nil
      end

      @current_workstation = workstation
      session[:current_workstation_id] = @current_workstation&.id
      persist_context_cookie(WORKSTATION_COOKIE_KEY, @current_workstation&.id)
      @current_workstation
    end

    def selected_branch_id_from_request
      selected_branch_param.presence || session[:current_branch_id] || cookies.signed[BRANCH_COOKIE_KEY]
    end

    def selected_workstation_id_from_request
      selected_workstation_param.presence || session[:current_workstation_id] || cookies.signed[WORKSTATION_COOKIE_KEY]
    end

    def selected_branch_param
      return nil unless teller_context_assignment_request?

      params[:branch_id]
    end

    def selected_workstation_param
      return nil unless teller_context_assignment_request?

      params[:workstation_id]
    end

    def teller_context_assignment_request?
      controller_path == "teller/contexts" && action_name == "update"
    end

    def persist_context_cookie(key, value)
      if value.present?
        cookies.permanent.signed[key] = { value: value, httponly: true, same_site: :lax }
      else
        cookies.delete(key)
      end
    end

    def current_teller_session
      return @current_teller_session if defined?(@current_teller_session)

      session_id = session[:current_teller_session_id]
      teller_session = TellerSession.find_by(id: session_id)

      if teller_session.present? && !teller_session.open?
        teller_session = nil
      end

      @current_teller_session = teller_session
      session[:current_teller_session_id] = @current_teller_session&.id
      @current_teller_session
    end
end
