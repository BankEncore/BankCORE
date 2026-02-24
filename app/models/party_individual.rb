# frozen_string_literal: true

class PartyIndividual < ApplicationRecord
  GOVT_ID_TYPES = %w[driver_license state_id passport other].freeze

  encrypts :govt_id, deterministic: true

  belongs_to :party

  after_save :sync_party_display_name

  validates :last_name, presence: true
  validates :first_name, presence: true
  validates :govt_id_type, inclusion: { in: GOVT_ID_TYPES }, allow_blank: true

  private

    def sync_party_display_name
      party.update_column(:display_name, [ first_name, last_name ].compact_blank.join(" "))
    end
end
