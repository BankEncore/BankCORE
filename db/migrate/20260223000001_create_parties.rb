class CreateParties < ActiveRecord::Migration[8.1]
  def change
    create_table :parties do |t|
      t.string :party_kind, null: false
      t.string :relationship_kind, null: false
      t.string :display_name
      t.boolean :is_active, null: false, default: true
      t.string :tax_id
      t.string :street_address
      t.string :city
      t.string :state, limit: 2
      t.string :zip_code, limit: 10
      t.string :phone, limit: 20
      t.string :email

      t.timestamps
    end

    add_index :parties, :party_kind
    add_index :parties, :relationship_kind
    add_index :parties, :is_active
  end
end
