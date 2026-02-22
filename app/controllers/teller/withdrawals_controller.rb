module Teller
  class WithdrawalsController < BaseController
    include PostingPrerequisites
    include TellerPostingExecution

    before_action :ensure_authorized
    before_action :require_posting_context!

    def new
      @teller_session = current_teller_session
      @transaction_type = "withdrawal"
      @page_title = "Withdrawal"
      @form_url = teller_withdrawals_path
      render "teller/transaction_pages/show"
    end

    def create
      execute_posting(forced_transaction_type: "withdrawal")
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end
  end
end
