# frozen_string_literal: true

class AddIncomeFeeToLedgerReferences < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:ledger_references)
    return if LedgerReference.exists?(reference: "income:fee")

    LedgerReference.create!(reference: "income:fee", ref_type: "income_code", status: "active")
  end

  def down
  end
end
