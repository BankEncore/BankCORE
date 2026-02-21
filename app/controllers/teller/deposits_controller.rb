module Teller
  class DepositsController < ApplicationController
    include PostingPrerequisites
    include TellerPostingExecution

    before_action :ensure_authorized
    before_action :require_posting_context!

    def new
      @teller_session = current_teller_session
      @transaction_type = "deposit"
      @page_title = "Deposit"
      @form_url = teller_deposits_path
      render "teller/transaction_pages/show"
    end

    def create
      execute_posting(forced_transaction_type: "deposit")
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end
  end
end
