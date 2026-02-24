module Teller
  class DashboardController < BaseController
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
