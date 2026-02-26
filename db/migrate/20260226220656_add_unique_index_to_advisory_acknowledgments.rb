class AddUniqueIndexToAdvisoryAcknowledgments < ActiveRecord::Migration[8.1]
  def change
    add_index :advisory_acknowledgments, [ :advisory_id, :user_id ], unique: true
  end
end
