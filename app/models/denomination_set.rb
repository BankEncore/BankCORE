# frozen_string_literal: true

class DenominationSet < ApplicationRecord
  CONTEXTS = [ nil, "opening", "closing" ].freeze

  belongs_to :denominationable, polymorphic: true
  has_many :denomination_lines, dependent: :destroy

  validates :currency, presence: true
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :context, inclusion: { in: CONTEXTS }, allow_nil: true
end
