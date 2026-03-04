# frozen_string_literal: true

module Teller
  module Parts
    class CheckCashingsController < BaseController
      def new
        @teller_session = current_teller_session
        @transaction_type = "check_cashing"
        @page_title = "Check Cashing (Parts)"
        @form_url = teller_parts_check_cashings_path
        @parties = Party.where(is_active: true, party_kind: "individual").order(display_name: :asc).limit(50)
        @selected_party = Party.includes(:party_individual).find_by(id: params[:party_id]) if params[:party_id].present?
        render "teller/transaction_pages/show"
      end

      def create
        execute_posting(forced_transaction_type: "check_cashing")
      end

      private
        def ensure_authorized
          authorize([ :teller, :posting ], :create?)
        end
    end
  end
end
