module Teller
  class TellerSessionsController < BaseController
    def new
      authorize([ :teller, :teller_session ], :new?)
      @teller_session = current_teller_session
      @drawers = available_drawers
    end

    def create
      authorize([ :teller, :teller_session ], :create?)

      if current_branch.blank? || current_workstation.blank?
        redirect_to teller_context_path, alert: "Select branch and workstation before opening a teller session."
        return
      end

      if current_teller_session.present?
        redirect_to new_teller_teller_session_path, alert: "A teller session is already open."
        return
      end

      op = open_params.to_h.symbolize_keys
      drawer = available_drawers.find_by(id: op[:cash_location_id])
      if drawer.blank?
        redirect_to new_teller_teller_session_path, alert: "Select a valid drawer."
        return
      end

      opening_cents = op[:opening_cash_cents].to_i
      previous_closing = TellerSession.previous_closing_cents_for_drawer(drawer.id)

      teller_session = TellerSession.create!(
        user: Current.user,
        branch: current_branch,
        workstation: current_workstation,
        cash_location: drawer,
        opened_at: Time.current,
        opening_cash_cents: opening_cents
      )

      teller_session.cash_location_assignments.create!(cash_location: drawer, assigned_at: Time.current)

      if opening_cents != previous_closing
        Posting::SessionHandoffVarianceService.new(
          teller_session: teller_session,
          opening_cents: opening_cents,
          previous_closing_cents: previous_closing
        ).call
      end

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

      redirect_to consume_teller_return_to(teller_root_path), notice: "Teller session opened."
    end

    def previous_closing
      authorize([ :teller, :teller_session ], :new?)

      drawer = available_drawers.find_by(id: params[:cash_location_id])
      cents = drawer.present? ? TellerSession.previous_closing_cents_for_drawer(drawer.id) : 0

      render json: { previous_closing_cents: cents }
    end

    def close
      authorize([ :teller, :teller_session ], :close?)

      teller_session = current_teller_session
      if teller_session.blank?
        redirect_to new_teller_teller_session_path, alert: "No open teller session to close."
        return
      end

      declared_cents = close_params[:closing_cash_cents].to_i
      expected_cents = teller_session.expected_cash_cents
      variance_cents = declared_cents - expected_cents

      if variance_cents != 0 && teller_session.cash_location.present?
        Posting::SessionCloseVarianceService.new(
          teller_session: teller_session,
          declared_cents: declared_cents,
          expected_cents: expected_cents,
          variance_reason: close_params[:cash_variance_reason],
          variance_notes: close_params[:cash_variance_notes]
        ).call
      end

      teller_session.close!(
        declared_cents,
        variance_reason: close_params[:cash_variance_reason],
        variance_notes: close_params[:cash_variance_notes],
        expected_cents: expected_cents,
        variance_cents: variance_cents
      )
      AuditEvent.create!(
        event_type: "teller_session.closed",
        actor_user: Current.user,
        branch: teller_session.branch,
        workstation: teller_session.workstation,
        teller_session: teller_session,
        auditable: teller_session,
        metadata: {
          closing_cash_cents: teller_session.closing_cash_cents,
          expected_closing_cash_cents: teller_session.expected_closing_cash_cents,
          cash_variance_cents: teller_session.cash_variance_cents,
          cash_variance_reason: teller_session.cash_variance_reason,
          cash_variance_notes: teller_session.cash_variance_notes
        }.to_json,
        occurred_at: Time.current
      )

      session.delete(:current_teller_session_id)
      redirect_to new_teller_teller_session_path, notice: "Teller session closed."
    end

    private
      def open_params
        p = params[:teller_session].presence || params
        p.permit(:opening_cash_cents, :cash_location_id)
      end

      def close_params
        params.permit(:closing_cash_cents, :cash_variance_reason, :cash_variance_notes)
      end

      def available_drawers
        return CashLocation.none if current_branch.blank?

        CashLocation.active.drawers.where(branch_id: current_branch.id).order(:name)
      end
  end
end
