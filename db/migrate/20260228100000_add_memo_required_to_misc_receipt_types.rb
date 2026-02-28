# frozen_string_literal: true

class AddMemoRequiredToMiscReceiptTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :misc_receipt_types, :memo_required, :boolean, null: false, default: true
  end
end
