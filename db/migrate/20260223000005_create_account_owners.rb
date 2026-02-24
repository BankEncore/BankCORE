class CreateAccountOwners < ActiveRecord::Migration[8.1]
  def change
    create_table :account_owners do |t|
      t.references :account, null: false, foreign_key: true
      t.references :party, null: false, foreign_key: true
      t.boolean :is_primary, null: false

      t.timestamps
    end

    add_index :account_owners, [ :account_id, :party_id ], unique: true
  end
end
