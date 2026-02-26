# frozen_string_literal: true

class Advisory < ApplicationRecord
  # scope_type: party | account
  # workspace_visibility: teller | csr | both
  # severity: 0=Info, 1=Notice, 2=Alert, 3=RequiresAcknowledgment, 4=Restriction
  # category: fraud, compliance, legal, operational, relationship, monitoring

  enum :scope_type, { party: "party", account: "account" }
  enum :workspace_visibility, { teller: "teller", csr: "csr", both: "both" }
  enum :severity, {
    info: 0,
    notice: 1,
    alert: 2,
    requires_acknowledgment: 3,
    restriction: 4
  }, prefix: true

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :advisory_acknowledgments, dependent: :destroy

  validates :title, presence: true
  validates :category, inclusion: {
    in: %w[fraud compliance legal operational relationship monitoring],
    allow_nil: true
  }

  scope :active, -> {
    now = Time.current
    where("(effective_start_at IS NULL OR effective_start_at <= ?) AND (effective_end_at IS NULL OR effective_end_at > ?)", now, now)
  }
  scope :for_workspace, ->(workspace) {
    case workspace.to_s
    when "teller" then where(workspace_visibility: [ :teller, :both ])
    when "csr" then where(workspace_visibility: [ :csr, :both ])
    else all
    end
  }
  scope :ordered_for_display, -> { order(pinned: :desc, severity: :desc, effective_start_at: :desc) }
  scope :for_scope, ->(scope_type, scope_id) { where(scope_type:, scope_id:) }

  def scope_record
    return nil unless scope_type.present? && scope_id.present?
    scope_type.classify.constantize.find_by(id: scope_id)
  end
end
