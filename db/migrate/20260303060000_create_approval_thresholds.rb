# frozen_string_literal: true

class CreateApprovalThresholds < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_thresholds, charset: "utf8mb4", collation: "utf8mb4_general_ci" do |t|
      t.string :trigger_key, null: false
      t.string :transaction_type
      t.integer :threshold_cents, null: false
      t.string :policy_trigger, null: false

      t.timestamps
    end

    add_index :approval_thresholds, [ :trigger_key, :transaction_type ], unique: true, name: "index_approval_thresholds_on_trigger_and_type"
    add_index :approval_thresholds, :trigger_key

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          INSERT INTO approval_thresholds (trigger_key, transaction_type, threshold_cents, policy_trigger, created_at, updated_at)
          VALUES
            ('cash_in', '', 500000, 'cash_in_threshold', NOW(), NOW()),
            ('cash_out', '', 100000, 'cash_out_threshold', NOW(), NOW()),
            ('vault_transfer', '', 1000000, 'vault_transfer_threshold', NOW(), NOW()),
            ('amount', '', 100000, 'amount_threshold', NOW(), NOW())
        SQL
      end
    end
  end
end
