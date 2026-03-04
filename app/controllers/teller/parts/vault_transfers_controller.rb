# frozen_string_literal: true

module Teller
  module Parts
    class VaultTransfersController < BaseController
      def new
        @teller_session = current_teller_session
        @transaction_type = "vault_transfer"
        @page_title = "Vault Transfer (Parts)"
        @form_url = teller_parts_vault_transfers_path
        vaults = current_branch.cash_locations.active.where(location_type: "vault").order(:name)
        @cash_locations = @teller_session.cash_location.present? ? [ @teller_session.cash_location ] + vaults.to_a : vaults.to_a
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
end
