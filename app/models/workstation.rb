class Workstation < ApplicationRecord
  belongs_to :branch
  has_many :teller_sessions, dependent: :destroy
  has_many :teller_transactions, dependent: :destroy
  has_many :user_roles, dependent: :nullify

  validates :code, presence: true, uniqueness: { scope: :branch_id }
  validates :name, presence: true
end
