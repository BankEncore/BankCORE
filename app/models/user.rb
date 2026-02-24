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
  normalizes :teller_number, with: ->(t) { t.to_s.upcase.strip }

  before_validation :set_display_name, if: -> { display_name.blank? && (first_name.present? || last_name.present?) }

  validates :teller_number, length: { maximum: 4 }, uniqueness: { case_sensitive: false }, allow_blank: true

  attr_accessor :pin

  def display_label
    display_name.presence || email_address
  end

  def pin=(value)
    @pin = value
    self.password_hash = value.present? ? BCrypt::Password.create(value) : nil
  end

  def authenticate_pin(submitted_pin)
    return false if password_hash.blank? || submitted_pin.blank?
    BCrypt::Password.new(password_hash) == submitted_pin
  end

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

  private

    def set_display_name
      self.display_name = [ first_name, last_name.to_s[0] ].compact_blank.join(" ").presence
    end
end
