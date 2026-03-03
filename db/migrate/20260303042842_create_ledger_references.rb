class CreateLedgerReferences < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_references, charset: "utf8mb4", collation: "utf8mb4_general_ci" do |t|
      t.string :reference, null: false, limit: 255
      t.string :ref_type, null: false, limit: 64
      t.string :status, null: false, default: "active", limit: 32
      t.string :normal_balance, limit: 16
      t.text :metadata, size: :long, collation: "utf8mb4_bin"
      t.bigint :account_id
      t.bigint :cash_location_id
      t.timestamps
    end

    add_index :ledger_references, :reference, unique: true
    add_index :ledger_references, :ref_type
    add_index :ledger_references, :status
    add_index :ledger_references, :account_id
    add_index :ledger_references, :cash_location_id

    add_foreign_key :ledger_references, :accounts, column: :account_id
    add_foreign_key :ledger_references, :cash_locations, column: :cash_location_id

    add_check_constraint :ledger_references, "json_valid(`metadata`)", name: "ledger_references_metadata_valid"
  end
end
