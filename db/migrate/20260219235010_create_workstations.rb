class CreateWorkstations < ActiveRecord::Migration[8.1]
  def change
    create_table :workstations do |t|
      t.references :branch, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :workstations, [ :branch_id, :code ], unique: true
  end
end
