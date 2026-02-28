module Posting
  module Recipes
    class WithdrawalRecipe < BaseRecipe
      def normalized_entries
        generated_entries
      end

      private

      def generated_entries
        amount_cents = posting_params[:amount_cents].to_i
        primary_account_reference = posting_params[:primary_account_reference].to_s

        [
          { side: "debit", account_reference: primary_account_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: default_cash_account_reference, amount_cents: amount_cents }
        ]
      end
    end
  end
end
