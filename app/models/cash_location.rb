class CashLocation < ApplicationRecord
  TYPES = %w[drawer vault].freeze

  after_create :register_ledger_reference

  belongs_to :branch
  has_many :cash_location_assignments, dependent: :restrict_with_exception
  has_many :teller_sessions, dependent: :nullify
  has_many :cash_movements, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: { scope: :branch_id }
  validates :name, presence: true
  validates :location_type, inclusion: { in: TYPES }

  scope :drawers, -> { where(location_type: "drawer") }
  scope :active, -> { where(active: true) }

  private

  def register_ledger_reference
    return unless LedgerReference.table_exists?
    return if code == "unassigned"

    ref = "cash:#{code}"
    return if LedgerReference.exists?(reference: ref)

    LedgerReference.create!(reference: ref, ref_type: "cash_location", status: "active", cash_location_id: id)
  end
end
