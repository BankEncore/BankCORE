class CreateBranches < ActiveRecord::Migration[8.1]
  def change
    create_table :branches do |t|
      t.string :code, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :branches, :code, unique: true
  end
end
