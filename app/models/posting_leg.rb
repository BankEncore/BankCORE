class PostingLeg < ApplicationRecord
  SIDES = %w[debit credit].freeze

  belongs_to :posting_batch

  validates :side, inclusion: { in: SIDES }
  validates :account_reference, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }, uniqueness: { scope: :posting_batch_id }
end
