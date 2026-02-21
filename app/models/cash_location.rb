class CashLocation < ApplicationRecord
  TYPES = %w[drawer vault].freeze

  belongs_to :branch
  has_many :cash_location_assignments, dependent: :restrict_with_exception
  has_many :teller_sessions, dependent: :nullify
  has_many :cash_movements, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: { scope: :branch_id }
  validates :name, presence: true
  validates :location_type, inclusion: { in: TYPES }

  scope :drawers, -> { where(location_type: "drawer") }
  scope :active, -> { where(active: true) }
end
