class AccountTransaction < ApplicationRecord
  DIRECTIONS = %w[debit credit].freeze

  belongs_to :account, optional: true
  belongs_to :teller_transaction
  belongs_to :posting_batch

  validates :account_reference, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :amount_cents, numericality: { greater_than: 0 }
end
