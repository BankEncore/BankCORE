# frozen_string_literal: true

class AdvisoryService
  def self.check_posting_allowed(primary_account_reference:, party_id: nil, acknowledged_advisory_ids: [])
    account = Account.find_by(account_number: primary_account_reference.to_s.strip) if primary_account_reference.present?
    party_ids = []
    account_ids = []

    if account.present?
      account_ids << account.id
      primary = account.primary_owner
      party_ids << primary.id if primary.present?
    end
    party_ids << party_id.to_i if party_id.present?
    party_ids = party_ids.compact.uniq

    scopes = account_ids.map { |id| [ "account", id ] } + party_ids.map { |id| [ "party", id ] }
    return { allowed: true } if scopes.empty?

    advisories = scopes.flat_map do |scope_type, scope_id|
      Advisory
        .for_scope(scope_type, scope_id)
        .for_workspace("teller")
        .active
    end.uniq

    acked_ids = Set.new(Array(acknowledged_advisory_ids).map(&:to_i).compact)

    advisories.each do |a|
      if a.severity_restriction?
        return { allowed: false, error: "Transaction restricted", status: :forbidden, advisory: a }
      end

      if a.severity_requires_acknowledgment?
        next if acked_ids.include?(a.id)

        valid_ack = AdvisoryAcknowledgment
          .where(advisory: a, user: Current.user)
          .where("acknowledged_at >= ?", a.updated_at)
          .exists?

        next if valid_ack

        return { allowed: false, error: "Acknowledgment required", status: :unprocessable_entity, advisory: a }
      end
    end

    { allowed: true }
  end
end
