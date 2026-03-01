class AuditEvent < ApplicationRecord
  serialize :metadata, coder: JSON
  belongs_to :actor_user, class_name: "User", optional: true
  belongs_to :branch, optional: true
  belongs_to :workstation, optional: true
  belongs_to :teller_session, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :event_type, presence: true
  validates :occurred_at, presence: true
end
