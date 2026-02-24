# frozen_string_literal: true

class AddUserProfileFields < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :teller_number, :string, limit: 4
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :display_name, :string
    add_column :users, :password_hash, :string

    add_index :users, :teller_number, unique: true
  end
end
