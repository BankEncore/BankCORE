module Teller
  class ContextsController < ApplicationController
    def show
      authorize([ :teller, :dashboard ], :index?)

      @branches = Branch.order(:name)
      @teller_session = current_teller_session
      @workstations = if current_branch
        Workstation.where(branch_id: current_branch.id).order(:name)
      else
        Workstation.none
      end
      @drawers = if current_branch
        CashLocation.active.drawers.where(branch_id: current_branch.id).order(:name)
      else
        CashLocation.none
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

      if workstation.present? && workstation.branch_id != branch.id
        redirect_to teller_context_path, alert: "Workstation must belong to selected branch."
        return
      end

      session[:current_branch_id] = branch.id
      session[:current_workstation_id] = workstation&.id

      redirect_to teller_context_path, notice: "Session context updated."
    end

    private
      def context_params
        params.permit(:branch_id, :workstation_id)
      end
  end
end
