module Teller
  class CheckCashingsController < BaseController
    include PostingPrerequisites
    include TellerPostingExecution

    before_action :ensure_authorized
    before_action :require_posting_context!

    def new
      @teller_session = current_teller_session
      @transaction_type = "check_cashing"
      @page_title = "Check Cashing"
      @form_url = teller_check_cashings_path
      @parties = Party.where(is_active: true, party_kind: "individual").order(display_name: :asc).limit(50)
      @cash_locations = []
      render "teller/transaction_pages/show"
    end

    def create
      execute_posting(forced_transaction_type: "check_cashing")
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :check_cashing_create?)
      end
  end
end
