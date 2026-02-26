class CreateAdvisoryAcknowledgments < ActiveRecord::Migration[8.1]
  def change
    create_table :advisory_acknowledgments do |t|
      t.references :advisory, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :workstation, null: true, foreign_key: true
      t.references :teller_session, null: true, foreign_key: true
      t.datetime :acknowledged_at

      t.timestamps
    end
  end
end
