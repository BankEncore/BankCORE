# frozen_string_literal: true

class LedgerReference < ApplicationRecord
  REF_TYPES = %w[
    customer_account
    cash_location
    income_code
    expense_code
    liability
    check_clearing
  ].freeze

  STATUSES = %w[active inactive].freeze

  belongs_to :account, optional: true
  belongs_to :cash_location, optional: true

  validates :reference, presence: true, uniqueness: true
  validates :ref_type, presence: true, inclusion: { in: REF_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end
end
