# frozen_string_literal: true

class BillPayee < ApplicationRecord
  after_save :register_ledger_reference

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :liability_account_reference, presence: true
  validates :default_fee_amount_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:display_order, :name) }

  private

  def register_ledger_reference
    return unless LedgerReference.table_exists?

    ref = liability_account_reference.to_s.strip
    return if ref.blank?
    return if LedgerReference.exists?(reference: ref)

    LedgerReference.create!(reference: ref, ref_type: "liability", status: "active")
  end
end
