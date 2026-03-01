# frozen_string_literal: true

class AddContextToDenominationSets < ActiveRecord::Migration[8.1]
  def change
    add_column :denomination_sets, :context, :string
    add_index :denomination_sets, [ :denominationable_type, :denominationable_id, :context ],
      name: "index_denomination_sets_on_denom_and_context"
  end
end
