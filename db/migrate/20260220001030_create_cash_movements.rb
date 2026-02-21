class CreateCashMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_movements do |t|
      t.references :teller_transaction, null: false, foreign_key: true
      t.references :teller_session, null: false, foreign_key: true
      t.references :cash_location, null: false, foreign_key: true
      t.string :direction, null: false
      t.integer :amount_cents, null: false

      t.timestamps
    end

    add_index :cash_movements, :direction
  end
end
