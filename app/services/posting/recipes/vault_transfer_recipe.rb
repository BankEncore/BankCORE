module Posting
  module Recipes
    class VaultTransferRecipe < BaseRecipe
      def normalized_entries
        explicit_entries = Array(posting_params[:entries]).map { |entry| entry.to_h.symbolize_keys }
        explicit_entries.present? ? explicit_entries : generated_entries
      end

      def posting_metadata
        {
          vault_transfer: {
            direction: vault_transfer_direction,
            source_cash_account_reference: vault_transfer_source_reference,
            destination_cash_account_reference: vault_transfer_destination_reference,
            reason_code: posting_params[:vault_transfer_reason_code].to_s,
            memo: posting_params[:vault_transfer_memo].to_s
          }
        }
      end

      private

      def generated_entries
        amount_cents = posting_params[:amount_cents].to_i
        source_reference = vault_transfer_source_reference
        destination_reference = vault_transfer_destination_reference

        return [] if source_reference.blank? || destination_reference.blank?
        return [] if source_reference == destination_reference

        [
          { side: "debit", account_reference: destination_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: source_reference, amount_cents: amount_cents }
        ]
      end

      def vault_transfer_direction
        direction = posting_params[:vault_transfer_direction].to_s
        return direction if direction.in?([ "drawer_to_vault", "vault_to_drawer", "vault_to_vault" ])

        ""
      end

      def vault_transfer_source_reference
        case vault_transfer_direction
        when "drawer_to_vault"
          default_cash_account_reference
        when "vault_to_drawer", "vault_to_vault"
          posting_params[:vault_transfer_source_cash_account_reference].to_s
        else
          ""
        end
      end

      def vault_transfer_destination_reference
        case vault_transfer_direction
        when "drawer_to_vault", "vault_to_vault"
          posting_params[:vault_transfer_destination_cash_account_reference].to_s
        when "vault_to_drawer"
          default_cash_account_reference
        else
          ""
        end
      end
    end
  end
end
