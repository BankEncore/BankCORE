class CreatePartyIndividuals < ActiveRecord::Migration[8.1]
  def change
    create_table :party_individuals do |t|
      t.references :party, null: false, foreign_key: true, index: { unique: true }
      t.string :last_name, null: false
      t.string :first_name, null: false
      t.date :dob
      t.string :govt_id_type
      t.string :govt_id

      t.timestamps
    end

  end
end
