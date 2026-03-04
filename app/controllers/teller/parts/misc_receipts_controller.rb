# frozen_string_literal: true

module Teller
  module Parts
    class MiscReceiptsController < BaseController
      def new
        @teller_session = current_teller_session
        @transaction_type = "misc_receipt"
        @page_title = "Misc Receipt (Parts)"
        @form_url = teller_parts_misc_receipts_path
        @misc_receipt_types = MiscReceiptType.active.ordered
        @parties = Party.where(is_active: true, party_kind: "individual").order(display_name: :asc).limit(50)
        @selected_party = Party.includes(:party_individual).find_by(id: params[:party_id]) if params[:party_id].present?
        @cash_locations = []
        render "teller/transaction_pages/show"
      end

      def create
        execute_posting(forced_transaction_type: "misc_receipt")
      end

      private
        def ensure_authorized
          authorize([ :teller, :posting ], :misc_receipt_create?)
        end
    end
  end
end
