class CreatePostingLegs < ActiveRecord::Migration[8.1]
  def change
    create_table :posting_legs do |t|
      t.references :posting_batch, null: false, foreign_key: true
      t.string :side, null: false
      t.string :account_reference, null: false
      t.integer :amount_cents, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :posting_legs, [ :posting_batch_id, :position ], unique: true
    add_index :posting_legs, :side
  end
end
