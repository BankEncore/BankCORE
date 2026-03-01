# frozen_string_literal: true

class CreateCashDenominations < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_denominations do |t|
      t.string :code, null: false, index: { unique: true }
      t.string :kind, null: false
      t.integer :face_value_cents, null: false, default: 0
      t.integer :roll_value_cents
      t.integer :coins_per_roll
      t.string :display_label, null: false
      t.integer :sort_order, null: false, default: 0
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :cash_denominations, [ :kind, :sort_order ]
  end
end
