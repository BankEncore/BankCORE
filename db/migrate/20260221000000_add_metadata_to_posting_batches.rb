class AddMetadataToPostingBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :posting_batches, :metadata, :json
  end
end
