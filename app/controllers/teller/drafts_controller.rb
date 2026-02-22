module Teller
  class DraftsController < BaseController
    include PostingPrerequisites
    include TellerPostingExecution

    before_action :ensure_authorized
    before_action :require_posting_context!

    def new
      @teller_session = current_teller_session
      @transaction_type = "draft"
      @page_title = "Draft Issuance"
      @form_url = teller_drafts_path
      render "teller/transaction_pages/show"
    end

    def create
      execute_posting(forced_transaction_type: "draft")
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :draft_create?)
      end
  end
end
