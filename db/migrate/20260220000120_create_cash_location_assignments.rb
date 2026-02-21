class CreateCashLocationAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_location_assignments do |t|
      t.references :teller_session, null: false, foreign_key: true
      t.references :cash_location, null: false, foreign_key: true
      t.datetime :assigned_at, null: false
      t.datetime :released_at

      t.timestamps
    end

    add_index :cash_location_assignments,
      [ :teller_session_id, :cash_location_id, :assigned_at ],
      name: "idx_cash_location_assignments_lifecycle"
  end
end
