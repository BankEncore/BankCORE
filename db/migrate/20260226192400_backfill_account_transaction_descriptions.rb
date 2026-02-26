# frozen_string_literal: true

class BackfillAccountTransactionDescriptions < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:account_transactions, :description)

    AccountTransaction.find_each do |at|
      next if at.description.present?

      desc = build_description_for(at)
      at.update_column(:description, desc) if desc.present?
    end
  end

  def down
    # No-op: backfill is additive
  end

  private

  def build_description_for(at)
    tt = at.teller_transaction
    pb = at.posting_batch
    return nil if tt.blank? || pb.blank?

    legs = pb.posting_legs.order(:position).map do |pl|
      {
        side: pl.side,
        account_reference: pl.account_reference,
        amount_cents: pl.amount_cents,
        position: pl.position
      }.symbolize_keys
    end

    leg = legs.find { |l| l[:account_reference] == at.account_reference && l[:side] == at.direction }
    return nil if leg.blank?

    if tt.transaction_type == "reversal"
      original_pb = pb.reversal_of_posting_batch_id ? PostingBatch.find_by(id: pb.reversal_of_posting_batch_id) : nil
      original_pb ||= tt.reversal_of_teller_transaction&.posting_batch
      return nil if original_pb.blank?

      original_desc = Posting::AccountTransactionDescriptionBuilder.original_description_for_leg(leg, original_pb)
      original_desc.present? ? "Reversal of #{original_desc}" : nil
    else
      Posting::AccountTransactionDescriptionBuilder.new(
        leg: leg,
        legs: legs,
        transaction_type: tt.transaction_type,
        metadata: pb.metadata || {},
        branch: tt.branch
      ).call
    end
  end
end
