class PostingBatch < ApplicationRecord
  STATUSES = %w[committed].freeze

  attribute :metadata, :json, default: {}

  belongs_to :teller_transaction
  belongs_to :reversal_of_posting_batch, class_name: "PostingBatch", optional: true
  has_one :reversed_by_posting_batch, class_name: "PostingBatch", foreign_key: :reversal_of_posting_batch_id
  has_many :posting_legs, dependent: :destroy
  has_many :account_transactions, dependent: :destroy

  validates :request_id, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :committed_at, presence: true
end
