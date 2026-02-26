class CreateAdvisories < ActiveRecord::Migration[8.1]
  def change
    create_table :advisories do |t|
      t.string :scope_type
      t.bigint :scope_id
      t.string :category
      t.string :title
      t.text :body
      t.integer :severity
      t.string :workspace_visibility
      t.datetime :effective_start_at
      t.datetime :effective_end_at
      t.boolean :pinned, default: false, null: false
      t.string :restriction_code
      t.bigint :created_by_id
      t.bigint :updated_by_id

      t.timestamps
    end

    add_index :advisories, [ :scope_type, :scope_id ]
  end
end
