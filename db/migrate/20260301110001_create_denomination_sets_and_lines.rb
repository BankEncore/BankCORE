# frozen_string_literal: true

class CreateDenominationSetsAndLines < ActiveRecord::Migration[8.1]
  def change
    create_table :denomination_sets do |t|
      t.string :denominationable_type, null: false
      t.bigint :denominationable_id, null: false
      t.string :currency, null: false, default: "USD"
      t.integer :total_cents, null: false, default: 0

      t.timestamps
    end

    add_index :denomination_sets, [ :denominationable_type, :denominationable_id ],
      name: "index_denomination_sets_on_denominationable"

    create_table :denomination_lines do |t|
      t.references :denomination_set, null: false, foreign_key: true
      t.references :cash_denomination, null: false, foreign_key: true
      t.integer :qty
      t.integer :amount_cents, null: false, default: 0

      t.timestamps
    end

    add_index :denomination_lines, [ :denomination_set_id, :cash_denomination_id ],
      unique: true,
      name: "index_denomination_lines_on_set_and_denomination"
  end
end
