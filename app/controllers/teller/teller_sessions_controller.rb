module Teller
  class TellerSessionsController < ApplicationController
    def new
      authorize([ :teller, :teller_session ], :new?)
      @drawers = available_drawers
    end

    def create
      authorize([ :teller, :teller_session ], :create?)

      if current_branch.blank? || current_workstation.blank?
        redirect_to teller_context_path, alert: "Select branch and workstation before opening a teller session."
        return
      end

      if current_teller_session.present?
        redirect_to teller_context_path, alert: "A teller session is already open."
        return
      end

      teller_session = TellerSession.create!(
        user: Current.user,
        branch: current_branch,
        workstation: current_workstation,
        opened_at: Time.current,
        opening_cash_cents: open_params[:opening_cash_cents].to_i
      )

      session[:current_teller_session_id] = teller_session.id
      AuditEvent.create!(
        event_type: "teller_session.opened",
        actor_user: Current.user,
        branch: current_branch,
        workstation: current_workstation,
        teller_session: teller_session,
        auditable: teller_session,
        occurred_at: Time.current
      )

      redirect_to teller_context_path, notice: "Teller session opened."
    end

    def assign_drawer
      authorize([ :teller, :teller_session ], :assign_drawer?)

      teller_session = current_teller_session
      if teller_session.blank?
        redirect_to teller_context_path, alert: "Open a teller session first."
        return
      end

      drawer = available_drawers.find_by(id: params[:cash_location_id])
      if drawer.blank?
        redirect_to teller_context_path, alert: "Select a valid drawer."
        return
      end

      teller_session.assign_drawer!(drawer)
      AuditEvent.create!(
        event_type: "teller_session.drawer_assigned",
        actor_user: Current.user,
        branch: current_branch,
        workstation: current_workstation,
        teller_session: teller_session,
        auditable: drawer,
        metadata: { cash_location_id: drawer.id }.to_json,
        occurred_at: Time.current
      )

      redirect_to teller_context_path, notice: "Drawer assigned."
    end

    def close
      authorize([ :teller, :teller_session ], :close?)

      teller_session = current_teller_session
      if teller_session.blank?
        redirect_to teller_context_path, alert: "No open teller session to close."
        return
      end

      teller_session.close!(close_params[:closing_cash_cents].to_i)
      AuditEvent.create!(
        event_type: "teller_session.closed",
        actor_user: Current.user,
        branch: teller_session.branch,
        workstation: teller_session.workstation,
        teller_session: teller_session,
        auditable: teller_session,
        metadata: { closing_cash_cents: close_params[:closing_cash_cents].to_i }.to_json,
        occurred_at: Time.current
      )

      session.delete(:current_teller_session_id)
      redirect_to teller_context_path, notice: "Teller session closed."
    end

    private
      def open_params
        params.permit(:opening_cash_cents)
      end

      def close_params
        params.permit(:closing_cash_cents)
      end

      def available_drawers
        return CashLocation.none if current_branch.blank?

        CashLocation.active.drawers.where(branch_id: current_branch.id).order(:name)
      end
  end
end
