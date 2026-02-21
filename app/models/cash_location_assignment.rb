class CashLocationAssignment < ApplicationRecord
  belongs_to :teller_session
  belongs_to :cash_location

  validates :assigned_at, presence: true
end
