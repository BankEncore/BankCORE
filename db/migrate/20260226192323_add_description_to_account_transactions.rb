class AddDescriptionToAccountTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :account_transactions, :description, :string, limit: 255
  end
end
