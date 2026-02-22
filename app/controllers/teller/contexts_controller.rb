module Teller
  class ContextsController < BaseController
    def show
      authorize([ :teller, :dashboard ], :index?)

      @branches = Branch.order(:name)
      @workstations = if current_branch
        Workstation.where(branch_id: current_branch.id).order(:name)
      else
        Workstation.none
      end
    end

    def update
      authorize([ :teller, :dashboard ], :index?)

      branch = Branch.find_by(id: context_params[:branch_id])
      workstation = Workstation.find_by(id: context_params[:workstation_id])

      if branch.blank?
        redirect_to teller_context_path, alert: "Please select a valid branch."
        return
      end

      if workstation.blank?
        redirect_to teller_context_path, alert: "Please select a valid workstation."
        return
      end

      if workstation.present? && workstation.branch_id != branch.id
        redirect_to teller_context_path, alert: "Workstation must belong to selected branch."
        return
      end

      session[:current_branch_id] = branch.id
      session[:current_workstation_id] = workstation&.id

      redirect_to consume_teller_return_to(new_teller_teller_session_path), notice: "Context updated. Continue with teller session setup."
    end

    private
      def context_params
        params.permit(:branch_id, :workstation_id)
      end
  end
end
