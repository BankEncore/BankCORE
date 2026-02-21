class Current < ActiveSupport::CurrentAttributes
  attribute :session, :branch, :workstation, :teller_session
  delegate :user, to: :session, allow_nil: true
end
