# frozen_string_literal: true

class Party < ApplicationRecord
  PARTY_KINDS = %w[individual organization].freeze
  RELATIONSHIP_KINDS = %w[customer non_customer].freeze

  encrypts :tax_id, deterministic: true

  has_one :party_individual, dependent: :destroy
  has_one :party_organization, dependent: :destroy
  has_many :account_owners, dependent: :destroy
  has_many :accounts, through: :account_owners

  validates :party_kind, presence: true, inclusion: { in: PARTY_KINDS }
  validates :relationship_kind, presence: true, inclusion: { in: RELATIONSHIP_KINDS }
  validates :is_active, inclusion: { in: [ true, false ] }

  before_save :sync_display_name

  def individual?
    party_kind == "individual"
  end

  def organization?
    party_kind == "organization"
  end

  def customer?
    relationship_kind == "customer"
  end

  # Parties that share jointly owned accounts with this party (accounts with >1 owner)
  def related_parties
    my_account_ids = AccountOwner.where(party_id: id).pluck(:account_id)
    joint_account_ids = AccountOwner
      .where(account_id: my_account_ids)
      .group(:account_id)
      .having("COUNT(*) > 1")
      .pluck(:account_id)

    return Party.none if joint_account_ids.empty?

    Party
      .joins(:account_owners)
      .where(account_owners: { account_id: joint_account_ids })
      .where.not(id: id)
      .distinct
      .order(:display_name)
  end

  private

    def sync_display_name
      self.display_name = computed_display_name
    end

    def computed_display_name
      if individual? && party_individual.present?
        [ party_individual.first_name, party_individual.last_name ].compact_blank.join(" ")
      elsif organization? && party_organization.present?
        party_organization.legal_name
      else
        display_name.presence
      end
    end
end
