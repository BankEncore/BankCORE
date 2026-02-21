class CreatePostingBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :posting_batches do |t|
      t.references :teller_transaction, null: false, foreign_key: true
      t.string :request_id, null: false
      t.string :currency, null: false, default: "USD"
      t.string :status, null: false, default: "committed"
      t.datetime :committed_at, null: false

      t.timestamps
    end

    add_index :posting_batches, :request_id, unique: true
  end
end
