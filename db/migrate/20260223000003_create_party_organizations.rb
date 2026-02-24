class CreatePartyOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :party_organizations do |t|
      t.references :party, null: false, foreign_key: true, index: { unique: true }
      t.string :legal_name, null: false
      t.string :dba_name

      t.timestamps
    end

  end
end
