module Teller
  class ReceiptsController < BaseController
    before_action :load_posting_batch
    before_action :ensure_authorized

    def show # test
      @teller_transaction = @posting_batch.teller_transaction
      @posting_legs = @posting_batch.posting_legs.order(:position)
      @cash_movements = @teller_transaction.cash_movements.includes(:cash_location)

      if params[:view] == "audit"
        render :audit, layout: "application"
      end
    end

    private
      def ensure_authorized
        authorize([ :teller, @posting_batch ], :show?)
      end

      def load_posting_batch
        @posting_batch = PostingBatch
          .includes(:posting_legs, { account_transactions: :account }, teller_transaction: [ :branch, :workstation, :user, { teller_session: :cash_location } ])
          .find_by!(request_id: params[:request_id].to_s)
      end
  end
end
