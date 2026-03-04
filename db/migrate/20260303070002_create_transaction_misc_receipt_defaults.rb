# frozen_string_literal: true

class CreateTransactionMiscReceiptDefaults < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_misc_receipt_defaults, charset: "utf8mb4", collation: "utf8mb4_general_ci" do |t|
      t.string :transaction_type, null: false
      t.references :misc_receipt_type, null: false, foreign_key: true
      t.integer :display_order, default: 0, null: false
      t.boolean :mandatory, default: false, null: false
      t.string :override_policy, null: false, default: "supervisor_override"
      t.integer :default_amount_cents

      t.timestamps
    end

    add_index :transaction_misc_receipt_defaults, [ :transaction_type, :misc_receipt_type_id ],
      unique: true, name: "index_tmrd_on_transaction_type_and_misc_receipt_type"
    add_index :transaction_misc_receipt_defaults, :transaction_type
  end
end
