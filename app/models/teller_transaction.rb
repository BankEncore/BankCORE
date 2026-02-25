class TellerTransaction < ApplicationRecord
  NON_REVERSIBLE_TYPES = %w[session_close_variance session_handoff_variance reversal].freeze
  TRANSACTION_TYPES = %w[deposit withdrawal transfer vault_transfer draft check_cashing session_close_variance session_handoff_variance reversal].freeze
  STATUSES = %w[posted failed].freeze

  belongs_to :user
  belongs_to :teller_session
  belongs_to :branch
  belongs_to :workstation
  belongs_to :approved_by_user, class_name: "User", optional: true
  belongs_to :reversal_of_teller_transaction, class_name: "TellerTransaction", optional: true
  has_one :reversed_by_teller_transaction, class_name: "TellerTransaction", foreign_key: :reversal_of_teller_transaction_id
  has_one :posting_batch, dependent: :destroy
  has_many :cash_movements, dependent: :destroy
  has_many :account_transactions, dependent: :destroy

  scope :reversible, -> { where(transaction_type: TRANSACTION_TYPES - NON_REVERSIBLE_TYPES).where(reversed_by_teller_transaction_id: nil) }

  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }
  validates :request_id, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :posted_at, presence: true

  def reversed?
    reversed_by_teller_transaction_id.present?
  end

  def reversible?
    return false if NON_REVERSIBLE_TYPES.include?(transaction_type)
    return false if reversed?

    true
  end
end
