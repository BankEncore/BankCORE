class CreateTellerSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :teller_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.references :workstation, null: false, foreign_key: true
      t.references :cash_location, foreign_key: true
      t.string :status, null: false, default: "open"
      t.integer :opening_cash_cents, null: false, default: 0
      t.integer :closing_cash_cents
      t.datetime :opened_at, null: false
      t.datetime :closed_at

      t.timestamps
    end

    add_index :teller_sessions, [ :user_id, :status ]
    add_index :teller_sessions, [ :branch_id, :workstation_id, :status ], name: "idx_teller_sessions_branch_workstation_status"
  end
end
