# frozen_string_literal: true

class CashDenomination < ApplicationRecord
  KINDS = %w[bill coin_loose coin_roll].freeze

  validates :code, presence: true, uniqueness: true
  validates :kind, inclusion: { in: KINDS }
  validates :face_value_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :display_label, presence: true
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :roll_value_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :coins_per_roll, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  has_many :denomination_lines, dependent: :restrict_with_exception

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:sort_order, :id) }

  def self.enabled_for_display
    enabled.ordered
  end

  # Unit value for computing amount from qty (bills/loose use face_value; rolls use roll_value)
  def unit_value_cents
    if kind == "coin_roll"
      roll_value_cents
    else
      face_value_cents
    end
  end

  def bill?
    kind == "bill"
  end

  def coin_loose?
    kind == "coin_loose"
  end

  def coin_roll?
    kind == "coin_roll"
  end

  def must_divide_evenly?
    bill? || coin_roll?
  end
end
