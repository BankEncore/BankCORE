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
  validates :expected_closing_cash_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :opened_at, presence: true

  scope :open_sessions, -> { where(status: "open") }

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

  def net_cash_movement_cents
    cash_in_cents = cash_movements.where(direction: "in").sum(:amount_cents)
    cash_out_cents = cash_movements.where(direction: "out").sum(:amount_cents)

    cash_in_cents - cash_out_cents
  end

  def expected_cash_cents
    opening_cash_cents + net_cash_movement_cents
  end

  def close!(declared_cash_cents, variance_reason: nil, variance_notes: nil)
    expected_cents = expected_cash_cents
    variance_cents = declared_cash_cents - expected_cents

    update!(
      status: "closed",
      closing_cash_cents: declared_cash_cents,
      expected_closing_cash_cents: expected_cents,
      cash_variance_cents: variance_cents,
      cash_variance_reason: variance_reason.presence,
      cash_variance_notes: variance_notes.presence,
      closed_at: Time.current
    )
  end
end
