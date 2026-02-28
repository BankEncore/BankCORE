# frozen_string_literal: true

class BackfillPostingLegStructuredColumns < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:posting_legs, :reference_type)

    PostingLeg.find_each do |leg|
      metadata = check_metadata_for_leg(leg)
      parsed = Posting::AccountReferenceParser.parse(leg.account_reference, metadata: metadata)

      leg.update_columns(
        reference_type: parsed[:reference_type],
        reference_identifier: parsed[:reference_identifier],
        check_routing_number: parsed[:check_routing_number],
        check_account_number: parsed[:check_account_number],
        check_number: parsed[:check_number],
        check_type: parsed[:check_type]
      )
    end
  end

  def down
    # No-op: backfill is additive; we don't clear columns
  end

  private

  def check_metadata_for_leg(leg)
    return {} unless leg.account_reference.to_s.start_with?("check:")

    batch = leg.posting_batch
    return {} if batch.blank?

    meta = batch.metadata || {}
    meta = meta.with_indifferent_access if meta.respond_to?(:with_indifferent_access)

    check_items = meta["check_items"] || meta[:check_items]
    check_items ||= meta.dig("check_cashing", "check_items") || meta.dig(:check_cashing, :check_items)
    check_items = Array(check_items)

    item = check_items.find do |ci|
      (ci["account_reference"] || ci[:account_reference]).to_s == leg.account_reference
    end

    return {} if item.blank?

    item = item.with_indifferent_access if item.respond_to?(:with_indifferent_access)
    { "check_type" => (item["check_type"] || item[:check_type]).to_s.presence || "transit" }
  end
end
