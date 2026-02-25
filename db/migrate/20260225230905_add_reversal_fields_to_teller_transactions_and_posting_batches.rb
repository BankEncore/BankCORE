class AddReversalFieldsToTellerTransactionsAndPostingBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :teller_transactions, :reversal_of_teller_transaction_id, :bigint
    add_column :teller_transactions, :reversed_by_teller_transaction_id, :bigint
    add_column :teller_transactions, :reversed_at, :datetime
    add_column :teller_transactions, :reversal_reason_code, :string
    add_column :teller_transactions, :reversal_memo, :text

    add_index :teller_transactions, :reversal_of_teller_transaction_id
    add_index :teller_transactions, :reversed_by_teller_transaction_id, unique: true

    add_foreign_key :teller_transactions, :teller_transactions, column: :reversal_of_teller_transaction_id
    add_foreign_key :teller_transactions, :teller_transactions, column: :reversed_by_teller_transaction_id

    add_column :posting_batches, :reversal_of_posting_batch_id, :bigint
    add_index :posting_batches, :reversal_of_posting_batch_id
    add_foreign_key :posting_batches, :posting_batches, column: :reversal_of_posting_batch_id
  end
end
