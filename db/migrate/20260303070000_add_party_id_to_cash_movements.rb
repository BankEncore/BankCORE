# frozen_string_literal: true

class AddPartyIdToCashMovements < ActiveRecord::Migration[8.1]
  def change
    add_reference :cash_movements, :party, null: true, foreign_key: true, index: true
  end
end
