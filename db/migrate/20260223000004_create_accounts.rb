class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :account_number, limit: 16, null: false
      t.string :account_type, null: false
      t.references :branch, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.date :opened_on, null: false, default: -> { "CURRENT_DATE" }
      t.date :closed_on
      t.datetime :last_activity_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    add_index :accounts, :account_number, unique: true
    add_index :accounts, :status
  end
end
