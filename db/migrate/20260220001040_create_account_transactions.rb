class CreateAccountTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :account_transactions do |t|
      t.references :teller_transaction, null: false, foreign_key: true
      t.references :posting_batch, null: false, foreign_key: true
      t.string :account_reference, null: false
      t.string :direction, null: false
      t.integer :amount_cents, null: false
      t.integer :running_balance_cents

      t.timestamps
    end

    add_index :account_transactions, :account_reference
    add_index :account_transactions, :direction
  end
end
