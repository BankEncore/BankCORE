module RequestContext
  extend ActiveSupport::Concern

  included do
    before_action :set_request_context
    helper_method :current_branch, :current_workstation, :current_teller_session
  end

  private
    def set_request_context
      Current.branch = current_branch
      Current.workstation = current_workstation
      Current.teller_session = current_teller_session
    end

    def current_branch
      return @current_branch if defined?(@current_branch)

      selected_branch_id = params[:branch_id].presence || session[:current_branch_id]
      @current_branch = Branch.find_by(id: selected_branch_id)
      session[:current_branch_id] = @current_branch&.id
      @current_branch
    end

    def current_workstation
      return @current_workstation if defined?(@current_workstation)

      selected_workstation_id = params[:workstation_id].presence || session[:current_workstation_id]
      workstation = Workstation.find_by(id: selected_workstation_id)

      if workstation.present? && current_branch.present? && workstation.branch_id != current_branch.id
        workstation = nil
      end

      @current_workstation = workstation
      session[:current_workstation_id] = @current_workstation&.id
      @current_workstation
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
