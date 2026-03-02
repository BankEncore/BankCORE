class AddLedgerBalanceCacheToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :ledger_balance_cents, :integer, null: false, default: 0
    add_column :accounts, :ledger_balance_updated_at, :datetime
  end
end
