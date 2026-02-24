class AddAccountIdToAccountTransactions < ActiveRecord::Migration[8.1]
  def change
    add_reference :account_transactions, :account, null: true, foreign_key: true

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE account_transactions at
          INNER JOIN accounts a ON a.account_number = at.account_reference
          SET at.account_id = a.id
        SQL
      end
    end
  end
end
