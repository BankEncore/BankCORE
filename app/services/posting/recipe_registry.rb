module Posting
  class RecipeRegistry
    RECIPES = {
      "deposit" => Recipes::DepositRecipe,
      "withdrawal" => Recipes::WithdrawalRecipe,
      "transfer" => Recipes::TransferRecipe,
      "check_cashing" => Recipes::CheckCashingRecipe,
      "draft" => Recipes::DraftRecipe,
      "vault_transfer" => Recipes::VaultTransferRecipe
    }.freeze

    def self.for(transaction_type)
      key = transaction_type.to_s
      RECIPES.fetch(key) { raise KeyError, "Unknown transaction type: #{key}" }
    end
  end
end
