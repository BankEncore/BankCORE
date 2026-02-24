# frozen_string_literal: true

class AccountOwner < ApplicationRecord
  belongs_to :account
  belongs_to :party

  validates :is_primary, inclusion: { in: [ true, false ] }
  validate :at_most_one_primary_per_account

  private

    def at_most_one_primary_per_account
      return unless is_primary?
      return unless account_id.present?

      existing = AccountOwner.where(account_id: account_id).where(is_primary: true)
      existing = existing.where.not(id: id) if persisted?
      if existing.exists?
        errors.add(:is_primary, "already has a primary owner")
      end
    end
end
