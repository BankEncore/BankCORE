class CreateCashLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_locations do |t|
      t.references :branch, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :location_type, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :cash_locations, [ :branch_id, :code ], unique: true
    add_index :cash_locations, :location_type
  end
end
