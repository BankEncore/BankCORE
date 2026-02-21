class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :role
  belongs_to :branch, optional: true
  belongs_to :workstation, optional: true

  validates :role_id, uniqueness: {
    scope: [ :user_id, :branch_id, :workstation_id ]
  }
end
