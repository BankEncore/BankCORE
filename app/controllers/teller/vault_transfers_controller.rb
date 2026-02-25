module Teller
  class VaultTransfersController < BaseController
    include PostingPrerequisites
    include TellerPostingExecution

    before_action :ensure_authorized
    before_action :require_posting_context!

    def new
      @teller_session = current_teller_session
      @transaction_type = "vault_transfer"
      @page_title = "Vault Transfer"
      @form_url = teller_vault_transfers_path
      vaults = current_branch.cash_locations.active.where(location_type: "vault").order(:name)
      @cash_locations = (@teller_session.cash_location.present? ? [ @teller_session.cash_location ] + vaults.to_a : vaults)
      render "teller/transaction_pages/show"
    end

    def create
      execute_posting(forced_transaction_type: "vault_transfer")
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :vault_transfer_create?)
      end
  end
end
