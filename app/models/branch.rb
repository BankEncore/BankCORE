class Branch < ApplicationRecord
  has_many :cash_locations, dependent: :destroy
  has_many :teller_sessions, dependent: :destroy
  has_many :teller_transactions, dependent: :destroy
  has_many :workstations, dependent: :destroy
  has_many :user_roles, dependent: :nullify

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
