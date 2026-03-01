# frozen_string_literal: true

class DenominationLine < ApplicationRecord
  belongs_to :denomination_set
  belongs_to :cash_denomination

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :qty, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :qty_amount_consistency

  private

    def qty_amount_consistency
      return unless cash_denomination

      unit = cash_denomination.unit_value_cents
      return if unit.zero?
      return if qty.to_i.zero? && amount_cents.to_i.zero? # no entry for this line

      if qty.present? && qty.to_i.positive?
        expected = qty.to_i * unit
        if amount_cents.to_i != expected
          errors.add(:amount_cents, "must equal qty × #{cash_denomination.display_label} (#{expected}¢)")
        end
      elsif amount_cents.to_i.positive?
        if cash_denomination.must_divide_evenly? && (amount_cents.to_i % unit != 0)
          errors.add(:amount_cents, "must be a multiple of #{unit}¢ for #{cash_denomination.display_label}")
        end
      end
    end
end
