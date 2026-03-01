class AddIndexAccountOwnersAccountIdIsPrimary < ActiveRecord::Migration[8.1]
  def change
    add_index :account_owners, [ :account_id, :is_primary ]
  end
end
