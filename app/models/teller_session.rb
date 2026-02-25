class TellerSession < ApplicationRecord
  STATUSES = %w[open closed].freeze

  belongs_to :user
  belongs_to :branch
  belongs_to :workstation
  belongs_to :cash_location, optional: true
  has_many :cash_location_assignments, dependent: :destroy
  has_many :audit_events, dependent: :nullify
  has_many :teller_transactions, dependent: :destroy
  has_many :cash_movements, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :opening_cash_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :closing_cash_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :expected_closing_cash_cents, numericality: { only_integer: true }, allow_nil: true
  validates :opened_at, presence: true

  scope :open_sessions, -> { where(status: "open") }

  def self.previous_closing_cents_for_drawer(cash_location_id)
    return 0 if cash_location_id.blank?

    TellerSession.where(cash_location_id: cash_location_id, status: "closed")
      .order(closed_at: :desc).first&.closing_cash_cents || 0
  end

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
  end

  def assign_drawer!(drawer)
    transaction do
      update!(cash_location: drawer)
      cash_location_assignments.create!(cash_location: drawer, assigned_at: Time.current)
    end
  end

  def cash_in_cents
    cash_movements.where(direction: "in").sum(:amount_cents)
  end

  def cash_out_cents
    cash_movements.where(direction: "out").sum(:amount_cents)
  end

  def net_cash_movement_cents
    cash_in_cents - cash_out_cents
  end

  def checks_in_count
    deposit_transactions_with_checks.sum { |tt| (tt.posting_batch&.metadata&.dig("check_items") || []).size }
  end

  def checks_in_cents
    deposit_transactions_with_checks.sum do |tt|
      items = tt.posting_batch&.metadata&.dig("check_items") || []
      items.sum { |item| (item["amount_cents"] || item[:amount_cents] || 0).to_i }
    end
  end

  def expected_cash_cents
    opening_cash_cents + net_cash_movement_cents
  end

  def close!(declared_cash_cents, variance_reason: nil, variance_notes: nil, expected_cents: nil, variance_cents: nil)
    expected = expected_cents || expected_cash_cents
    variance = variance_cents || (declared_cash_cents - expected)

    update!(
      status: "closed",
      closing_cash_cents: declared_cash_cents,
      expected_closing_cash_cents: expected,
      cash_variance_cents: variance,
      cash_variance_reason: variance_reason.presence,
      cash_variance_notes: variance_notes.presence,
      closed_at: Time.current
    )
  end

  private
    def deposit_transactions_with_checks
      teller_transactions
        .where(transaction_type: "deposit", status: "posted")
        .includes(:posting_batch)
        .select { |tt| tt.posting_batch.present? }
    end
end
