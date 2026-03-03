# frozen_string_literal: true

class PartyCashDailyTotal < ApplicationRecord
  DEFAULT_THRESHOLD_CENTS = 1_000_000

  belongs_to :party

  validates :business_date, presence: true
  validates :cash_in_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :cash_out_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :for_date, ->(date) { where(business_date: date) }
  scope :exceeding_threshold, ->(threshold_cents: DEFAULT_THRESHOLD_CENTS) {
    where("cash_in_cents + cash_out_cents >= ?", threshold_cents)
  }

  def self.parties_exceeding_threshold(date:, threshold_cents: DEFAULT_THRESHOLD_CENTS)
    for_date(date).exceeding_threshold(threshold_cents: threshold_cents).includes(:party)
  end

  def total_cents
    cash_in_cents + cash_out_cents
  end
end
