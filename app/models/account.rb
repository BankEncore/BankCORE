# frozen_string_literal: true

class Account < ApplicationRecord
  ACCOUNT_TYPES = %w[checking savings deposit].freeze
  STATUSES = %w[open closed frozen restricted].freeze

  belongs_to :branch
  has_many :account_owners, dependent: :destroy
  has_many :account_transactions, dependent: :nullify
  has_many :parties, through: :account_owners

  validates :account_number, presence: true, uniqueness: true, length: { maximum: 16 }
  validates :account_type, presence: true, inclusion: { in: ACCOUNT_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opened_on, presence: true

  def account_reference
    account_number
  end

  def primary_owner
    account_owners.find_by(is_primary: true)&.party
  end

  def owners_ordered
    account_owners
      .joins(:party)
      .order("account_owners.is_primary DESC", "parties.display_name ASC")
  end

  def balance_cents
    credits = account_transactions.where(direction: "credit").sum(:amount_cents)
    debits = account_transactions.where(direction: "debit").sum(:amount_cents)
    credits - debits
  end
end
