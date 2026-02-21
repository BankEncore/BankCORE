class AddCloseoutFieldsToTellerSessions < ActiveRecord::Migration[8.1]
  def change
    change_table :teller_sessions, bulk: true do |t|
      t.integer :expected_closing_cash_cents
      t.integer :cash_variance_cents
      t.string :cash_variance_reason
      t.text :cash_variance_notes
    end
  end
end
