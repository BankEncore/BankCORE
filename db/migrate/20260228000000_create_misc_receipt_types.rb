# frozen_string_literal: true

class CreateMiscReceiptTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :misc_receipt_types do |t|
      t.string :code, null: false
      t.string :label, null: false
      t.string :income_account_reference, null: false
      t.integer :default_amount_cents
      t.boolean :is_active, null: false, default: true
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end

    add_index :misc_receipt_types, :code, unique: true
    add_index :misc_receipt_types, [ :is_active, :display_order ]
  end
end
