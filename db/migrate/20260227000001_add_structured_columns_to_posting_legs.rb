# frozen_string_literal: true

class AddStructuredColumnsToPostingLegs < ActiveRecord::Migration[8.1]
  def change
    add_column :posting_legs, :reference_type, :string
    add_column :posting_legs, :reference_identifier, :string
    add_column :posting_legs, :check_routing_number, :string
    add_column :posting_legs, :check_account_number, :string
    add_column :posting_legs, :check_number, :string
    add_column :posting_legs, :check_type, :string
  end
end
