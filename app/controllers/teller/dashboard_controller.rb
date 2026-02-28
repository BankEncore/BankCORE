module Teller
  class DashboardController < BaseController
    def last_transaction_primary_account
      authorize([ :teller, :dashboard ], :index?)
      teller_session = current_teller_session
      ref = if teller_session.present? && teller_session.open?
        last_tx = teller_session.teller_transactions
          .where(status: "posted")
          .order(posted_at: :desc, id: :desc)
          .limit(1)
          .includes(posting_batch: :posting_legs)
          .first
        last_tx&.primary_account_reference
      end
      render json: { ok: true, primary_account_reference: ref }
    end

    def last_transaction_served_party
      authorize([ :teller, :dashboard ], :index?)
      teller_session = current_teller_session
      payload = nil
      if teller_session.present? && teller_session.open?
        last_tx = teller_session.teller_transactions
          .where(status: "posted", transaction_type: %w[deposit withdrawal transfer draft check_cashing])
          .order(posted_at: :desc, id: :desc)
          .limit(20)
          .includes(posting_batch: [])
          .find { |tx| tx.posting_batch&.metadata&.dig("served_party", "party_id").present? }
        if last_tx
          meta = last_tx.posting_batch.metadata
          served = meta&.dig("served_party") || meta&.dig(:served_party) || {}
          party_id = (served["party_id"] || served[:party_id]).to_s.presence
          if party_id.present?
            party = Party.find_by(id: party_id)
            if party
              pi = party.party_individual
              govt_id_type = (pi&.govt_id_type == "driver_license" ? "drivers_license" : pi&.govt_id_type).to_s.presence
              govt_id = pi&.govt_id.to_s.presence
              payload = {
                party_id: party_id,
                display_name: party.display_name.presence || "Party ##{party.id}",
                govt_id_type: govt_id_type,
                govt_id: govt_id
              }
            end
          end
        end
      end
      render json: { ok: true }.merge(payload || {})
    end

    def index
      authorize([ :teller, :dashboard ], :index?)
      @teller_session = current_teller_session
      @cash_locations = current_branch.cash_locations.active.where(location_type: "vault").order(:name)

      if @teller_session.present? && @teller_session.open?
        @recent_transactions = @teller_session.teller_transactions
          .where(status: "posted")
          .order(posted_at: :desc, id: :desc)
          .limit(10)
          .includes(:posting_batch)
        @movements_by_type = build_movements_by_type
      end
    end

    private
      def build_movements_by_type
        counts = @teller_session.teller_transactions
          .where(status: "posted")
          .group(:transaction_type)
          .count
        sums_by_direction = CashMovement
          .where(teller_session_id: @teller_session.id)
          .joins(:teller_transaction)
          .where(teller_transactions: { status: "posted" })
          .group("teller_transactions.transaction_type", "cash_movements.direction")
          .sum(:amount_cents)

        TellerTransaction::TRANSACTION_TYPES.map do |transaction_type|
          count = counts.fetch(transaction_type, 0)
          in_cents = sums_by_direction.fetch([ transaction_type, "in" ], 0)
          out_cents = sums_by_direction.fetch([ transaction_type, "out" ], 0)
          net_cents = in_cents - out_cents
          { transaction_type: transaction_type, count: count, net_cents: net_cents }
        end
      end
  end
end
