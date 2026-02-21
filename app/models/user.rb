class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :teller_sessions, dependent: :destroy
  has_many :teller_transactions, dependent: :destroy
  has_many :audit_events, foreign_key: :actor_user_id, dependent: :nullify
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :role_permissions, through: :roles
  has_many :permissions, -> { distinct }, through: :role_permissions

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def has_permission?(permission_key, branch: nil, workstation: nil)
    scope = permissions.joins(roles: :user_roles)
      .where(permissions: { key: permission_key })
      .where(user_roles: { user_id: id })

    if branch
      scope = scope.where("user_roles.branch_id IS NULL OR user_roles.branch_id = ?", branch.id)
    end

    if workstation
      scope = scope.where("user_roles.workstation_id IS NULL OR user_roles.workstation_id = ?", workstation.id)
    end

    scope.exists?
  end
end
