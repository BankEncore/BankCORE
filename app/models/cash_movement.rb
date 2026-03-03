class CashMovement < ApplicationRecord
  DIRECTIONS = %w[in out].freeze

  belongs_to :teller_transaction
  belongs_to :teller_session
  belongs_to :cash_location
  belongs_to :party, optional: true

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :amount_cents, numericality: { greater_than: 0 }
end
