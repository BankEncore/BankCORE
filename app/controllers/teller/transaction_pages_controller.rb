module Teller
  class TransactionPagesController < BaseController
    include PostingPrerequisites

    before_action :ensure_authorized
    before_action :require_posting_context!
    before_action :set_teller_session

    def deposit
      render_page(transaction_type: "deposit", title: "Deposit")
    end

    def withdrawal
      render_page(transaction_type: "withdrawal", title: "Withdrawal")
    end

    def transfer
      render_page(transaction_type: "transfer", title: "Transfer")
    end

    def vault_transfer
      render_page(transaction_type: "vault_transfer", title: "Vault Transfer")
    end

    def draft
      render_page(transaction_type: "draft", title: "Draft Issuance")
    end

    def check_cashing
      render_page(transaction_type: "check_cashing", title: "Check Cashing")
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end

      def set_teller_session
        @teller_session = current_teller_session
      end

      def render_page(transaction_type:, title:)
        @transaction_type = transaction_type
        @page_title = title
        @cash_locations = current_branch.cash_locations.active.where(location_type: "vault").order(:name)
        @form_url = case transaction_type
        when "deposit"
          teller_deposits_path
        when "withdrawal"
          teller_withdrawals_path
        when "transfer"
          teller_transfers_path
        when "vault_transfer"
          teller_vault_transfers_path
        when "draft"
          teller_drafts_path
        when "check_cashing"
          teller_check_cashings_path
        else
          teller_posting_path
        end
        render :show
      end
  end
end
