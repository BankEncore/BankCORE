# frozen_string_literal: true

class CreatePartyCashDailyTotals < ActiveRecord::Migration[8.1]
  def change
    create_table :party_cash_daily_totals, charset: "utf8mb4", collation: "utf8mb4_general_ci" do |t|
      t.references :party, null: false, foreign_key: true
      t.date :business_date, null: false
      t.integer :cash_in_cents, default: 0, null: false
      t.integer :cash_out_cents, default: 0, null: false

      t.timestamps
    end

    add_index :party_cash_daily_totals, [ :party_id, :business_date ], unique: true, name: "index_party_cash_daily_totals_on_party_and_date"
    add_index :party_cash_daily_totals, :business_date
  end
end
