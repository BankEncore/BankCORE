class TellerTransaction < ApplicationRecord
  TRANSACTION_TYPES = %w[deposit withdrawal transfer check_cashing].freeze
  STATUSES = %w[posted failed].freeze

  belongs_to :user
  belongs_to :teller_session
  belongs_to :branch
  belongs_to :workstation
  has_one :posting_batch, dependent: :destroy
  has_many :cash_movements, dependent: :destroy
  has_many :account_transactions, dependent: :destroy

  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }
  validates :request_id, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :posted_at, presence: true
end
