class AdvisoryAcknowledgment < ApplicationRecord
  belongs_to :advisory
  belongs_to :user
  belongs_to :workstation, optional: true
  belongs_to :teller_session, optional: true
end
