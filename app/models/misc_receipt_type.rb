# frozen_string_literal: true

class MiscReceiptType < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :label, presence: true
  validates :income_account_reference, presence: true
  validates :default_amount_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:display_order, :label) }
end
