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

      denom_lines = open_denomination_lines.select { |l| (l[:amount_cents] || 0).to_i.positive? }
      if denom_lines.any?
        svc = DenominationBreakdownService.new
        catalog = CashDenomination.enabled.to_a
        lines = svc.parse_and_validate(denom_lines.map { |l| l.transform_keys(&:to_s) }, catalog)
        svc.persist!(teller_session, lines, context: "opening") if lines.any?
      end

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

      declared_cents = resolve_closing_cents(close_params)
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

      denom_set = nil
      denom_lines = Array(close_params[:denomination_lines]).map { |l| l.to_h.symbolize_keys }.select { |l| (l[:amount_cents] || 0).to_i.positive? }
      if denom_lines.any?
        svc = DenominationBreakdownService.new
        catalog = CashDenomination.enabled.to_a
        lines = svc.parse_and_validate(denom_lines.map { |l| l.transform_keys(&:to_s) }, catalog)
        denom_set = svc.persist!(teller_session, lines, context: "closing") if lines.any?
      end

      audit_metadata = {
        closing_cash_cents: teller_session.closing_cash_cents,
        expected_closing_cash_cents: teller_session.expected_closing_cash_cents,
        cash_variance_cents: teller_session.cash_variance_cents,
        cash_variance_reason: teller_session.cash_variance_reason,
        cash_variance_notes: teller_session.cash_variance_notes
      }
      audit_metadata[:denomination_set_id] = denom_set.id if denom_set.present?
      audit_metadata[:denomination_lines_count] = denom_set.denomination_lines.count if denom_set.present?
      audit_metadata[:denomination_total_cents] = denom_set.total_cents if denom_set.present?

      AuditEvent.create!(
        event_type: "teller_session.closed",
        actor_user: Current.user,
        branch: teller_session.branch,
        workstation: teller_session.workstation,
        teller_session: teller_session,
        auditable: teller_session,
        metadata: audit_metadata.to_json,
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

      def open_denomination_lines
        lines = params[:denomination_lines]
        lines ||= params[:teller_session]&.dig(:denomination_lines)
        Array(lines).map { |l| l.to_h.symbolize_keys }
      end

      def close_params
        params.permit(
          :closing_cash_cents,
          :cash_variance_reason,
          :cash_variance_notes,
          denomination_lines: [ :cash_denomination_id, :qty, :amount_cents ]
        )
      end

      def resolve_closing_cents(close_params)
        denom_lines = Array(close_params[:denomination_lines])
        if denom_lines.any?
          catalog = CashDenomination.enabled.index_by(&:id)
          total = 0
          denom_lines.each do |line|
            line = line.to_h.symbolize_keys
            id = line[:cash_denomination_id].to_s.strip.presence&.to_i
            next if id.blank? || catalog[id].nil?

            amt = line[:amount_cents].to_i
            qty = line[:qty].to_s.strip.presence&.to_i
            amt = qty * catalog[id].unit_value_cents if qty.present? && qty >= 0
            total += amt
          end
          return total if total.positive?
        end
        close_params[:closing_cash_cents].to_i
      end

      def available_drawers
        return CashLocation.none if current_branch.blank?

        CashLocation.active.drawers.where(branch_id: current_branch.id).order(:name)
      end
  end
end
