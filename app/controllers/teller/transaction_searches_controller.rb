# frozen_string_literal: true

module Teller
  class TransactionSearchesController < BaseController
    include PostingPrerequisites

    before_action :ensure_authorized
    before_action :require_posting_context!

    def index
      q = params[:q].to_s.strip
      parties = search_parties(q)
      accounts = search_accounts(q)
      render json: { parties: parties, accounts: accounts }
    end

    private

      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end

      def search_parties(q)
        scope = Party.where(is_active: true).order(display_name: :asc).limit(15)
        scope = scope.where("display_name LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(q)}%") if q.present?
        scope.pluck(:id, :display_name, :party_kind).map do |id, display_name, party_kind|
          { id: id, display_name: display_name.presence || "Party ##{id}", party_kind: party_kind }
        end
      end

      def search_accounts(q)
        return [] if q.blank?

        scope = Account
          .joins(:account_owners, :parties)
          .where("accounts.account_number LIKE ? OR parties.display_name LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(q)}%", "%#{ActiveRecord::Base.sanitize_sql_like(q)}%")
          .distinct
          .includes(:account_owners)
          .limit(15)

        scope.map do |account|
          {
            id: account.id,
            account_number: account.account_number,
            account_type: account.account_type,
            primary_owner_name: account.primary_owner&.display_name
          }
        end
      end
  end
end
