# frozen_string_literal: true

class AccountOwner < ApplicationRecord
  belongs_to :account
  belongs_to :party

  validates :is_primary, inclusion: { in: [ true, false ] }
  validate :party_not_already_owner

  before_validation :clear_other_primary, if: :is_primary?
  before_destroy :ensure_not_last_owner

  private

    def party_not_already_owner
      return unless account_id.present? && party_id.present?

      existing = AccountOwner.where(account_id: account_id, party_id: party_id)
      existing = existing.where.not(id: id) if persisted?
      if existing.exists?
        errors.add(:party_id, "is already an owner of this account")
      end
    end

    def clear_other_primary
      return unless account_id.present?

      scope = AccountOwner.where(account_id: account_id).where(is_primary: true)
      scope = scope.where.not(id: id) if persisted?
      scope.update_all(is_primary: false)
    end

    def ensure_not_last_owner
      return unless account
      return if account.account_owners.count > 1

      errors.add(:base, "Account must have at least one owner")
      throw :abort
    end
end
