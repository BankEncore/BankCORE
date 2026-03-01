# frozen_string_literal: true

class CreateBillPayees < ActiveRecord::Migration[8.1]
  def change
    create_table :bill_payees do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :liability_account_reference, null: false
      t.integer :default_fee_amount_cents
      t.boolean :memo_required, null: false, default: true
      t.boolean :is_active, null: false, default: true
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end

    add_index :bill_payees, :code, unique: true
    add_index :bill_payees, [ :is_active, :display_order ]
  end
end
