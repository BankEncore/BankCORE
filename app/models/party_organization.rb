# frozen_string_literal: true

class PartyOrganization < ApplicationRecord
  belongs_to :party

  after_save :sync_party_display_name

  validates :legal_name, presence: true

  private

    def sync_party_display_name
      party.update_column(:display_name, legal_name)
    end
end
