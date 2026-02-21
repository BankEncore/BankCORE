class PostingBatch < ApplicationRecord
  STATUSES = %w[committed].freeze

  belongs_to :teller_transaction
  has_many :posting_legs, dependent: :destroy
  has_many :account_transactions, dependent: :destroy

  validates :request_id, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :committed_at, presence: true
end
