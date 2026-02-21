class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.string :event_type, null: false
      t.references :actor_user, foreign_key: { to_table: :users }
      t.references :branch, foreign_key: true
      t.references :workstation, foreign_key: true
      t.references :teller_session, foreign_key: true
      t.references :auditable, polymorphic: true
      t.json :metadata
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :audit_events, :event_type
    add_index :audit_events, :occurred_at
  end
end
