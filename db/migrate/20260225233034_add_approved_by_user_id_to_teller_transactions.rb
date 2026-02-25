class AddApprovedByUserIdToTellerTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :teller_transactions, :approved_by_user_id, :bigint
    add_index :teller_transactions, :approved_by_user_id
    add_foreign_key :teller_transactions, :users, column: :approved_by_user_id
  end
end
