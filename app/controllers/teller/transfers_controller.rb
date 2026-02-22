module Teller
  class TransfersController < BaseController
    include PostingPrerequisites
    include TellerPostingExecution

    before_action :ensure_authorized
    before_action :require_posting_context!

    def new
      @teller_session = current_teller_session
      @transaction_type = "transfer"
      @page_title = "Transfer"
      @form_url = teller_transfers_path
      render "teller/transaction_pages/show"
    end

    def create
      execute_posting(forced_transaction_type: "transfer")
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end
  end
end
