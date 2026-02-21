class CreateTellerTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :teller_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :teller_session, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.references :workstation, null: false, foreign_key: true
      t.string :transaction_type, null: false
      t.string :request_id, null: false
      t.string :currency, null: false, default: "USD"
      t.integer :amount_cents, null: false
      t.string :status, null: false, default: "posted"
      t.datetime :posted_at, null: false

      t.timestamps
    end

    add_index :teller_transactions, :request_id, unique: true
    add_index :teller_transactions, [ :teller_session_id, :posted_at ]
  end
end
