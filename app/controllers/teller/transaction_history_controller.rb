module Teller
  class TransactionHistoryController < BaseController
    DEFAULT_LIMIT = 50
    MAX_LIMIT = 100

    def index
      authorize([ :teller, :dashboard ], :index?)

      @transactions = TellerTransaction
        .includes(:posting_batch)
        .where(user: Current.user, branch: current_branch, workstation: current_workstation, status: "posted")
        .where.not(posted_at: nil)
        .order(posted_at: :desc, id: :desc)
        .limit(history_limit)
    end

    private
      def history_limit
        requested = params[:limit].to_i
        return DEFAULT_LIMIT if requested <= 0

        [ requested, MAX_LIMIT ].min
      end
  end
end
