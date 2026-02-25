class AddDefaultWorkspaceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_workspace, :string
    add_index :users, :default_workspace
  end
end
