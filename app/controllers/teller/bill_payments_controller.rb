# frozen_string_literal: true

module Teller
  class BillPaymentsController < BaseController
    include PostingPrerequisites
    include TellerPostingExecution

    before_action :ensure_authorized
    before_action :require_posting_context!

    def new
      @teller_session = current_teller_session
      @transaction_type = "bill_payment"
      @page_title = "Bill Payment"
      @form_url = teller_bill_payments_path
      @bill_payees = BillPayee.active.ordered
      @parties = Party.where(is_active: true, party_kind: "individual").order(display_name: :asc).limit(50)
      @selected_party = Party.includes(:party_individual).find_by(id: params[:party_id]) if params[:party_id].present?
      @cash_locations = []
      render "teller/transaction_pages/show"
    end

    def create
      execute_posting(forced_transaction_type: "bill_payment")
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :bill_payment_create?)
      end
  end
end
