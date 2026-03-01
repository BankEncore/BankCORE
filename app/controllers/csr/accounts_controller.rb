# frozen_string_literal: true

module Csr
  class AccountsController < BaseController
    before_action :set_account, only: [ :show, :edit, :update ]
    before_action :set_branch_for_new, only: [ :new, :create ]
    before_action :ensure_authorized

    def index
      scope = Account.includes(:branch, :account_owners, :parties)
      scope = apply_accounts_index_filters(scope)
      scope = scope.reorder(account_number: :asc)
      per_page = [ 10, 25, 50, 100 ].include?(params[:per_page].to_i) ? params[:per_page].to_i : 10
      @pagy, @accounts = pagy(:offset, scope, limit: per_page)
    end

    def show
      @account_transactions = load_filtered_transactions
      @parties_for_owner = Party
        .where(is_active: true, relationship_kind: "customer")
        .where.not(id: @account.account_owners.select(:party_id))
        .order(:display_name)
        .limit(50)
    end

    def edit
      @branches = Branch.order(:code) if Current.user&.has_permission?("accounts.branch.edit")
    end

    def update
      if @account.update(account_update_params)
        redirect_to csr_account_path(@account), notice: "Account updated."
      else
        @parties = Party.where(is_active: true, relationship_kind: "customer").order(:display_name).limit(50)
        render :edit, status: :unprocessable_entity
      end
    end

    def new
      @account = Account.new(branch: @branch, status: "open", opened_on: Date.current)
      @parties = Party.where(is_active: true, relationship_kind: "customer").order(:display_name).limit(50)
    end

    def create
      @account = Account.new(account_params)
      if @account.save
        if owner_params_present?
          create_account_owners
          redirect_to csr_account_path(@account), notice: "Account created."
        else
          @account.errors.add(:base, "At least one owner (primary) is required")
          @parties = Party.where(is_active: true, relationship_kind: "customer").order(:display_name).limit(50)
          render :new, status: :unprocessable_entity
        end
      else
        @branch = @account.branch
        @parties = Party.where(is_active: true, relationship_kind: "customer").order(:display_name).limit(50)
        render :new, status: :unprocessable_entity
      end
    end

    private

      def set_account
        @account = Account.find(params[:id])
      end

      def set_branch_for_new
        @branch = Branch.find(params[:branch_id]) if params[:branch_id].present?
        @branch ||= current_branch
        redirect_to(csr_context_path, alert: "Select branch first.") and return if @branch.blank?
      end

      def ensure_authorized
        authorize([ :csr, @account || Account ], policy_class: Csr::AccountPolicy)
      end

      def account_params
        params.require(:account).permit(:account_number, :account_type, :branch_id, :status, :opened_on, :closed_on)
      end

      def account_update_params
        permitted = [ :account_number, :account_type, :status, :opened_on, :closed_on ]
        permitted << :branch_id if Current.user&.has_permission?("accounts.branch.edit")
        params.require(:account).permit(permitted)
      end

      def owner_params_present?
        params.dig(:account, :primary_party_id).present? || Array(params.dig(:account, :party_ids)).compact_blank.any?
      end

      def create_account_owners
        party_ids = Array(params.dig(:account, :party_ids)).compact_blank
        primary_party_id = params.dig(:account, :primary_party_id).presence
        party_ids << primary_party_id if primary_party_id.present?
        party_ids = party_ids.uniq

        party_ids.each_with_index do |party_id, idx|
          AccountOwner.create!(
            account: @account,
            party_id: party_id,
            is_primary: (primary_party_id.present? && party_id.to_s == primary_party_id.to_s) || (idx == 0 && primary_party_id.blank?)
          )
        end
      end

      def load_filtered_transactions
        scope = @account.account_transactions
          .includes(teller_transaction: :posting_batch)
          .joins(:teller_transaction)

        date_from = params[:date_from].presence || 30.days.ago.to_date
        date_to = params[:date_to].presence || Date.current
        if date_from.present?
          range_begin = Time.zone.parse("#{date_from} 00:00:00")
          scope = scope.where("teller_transactions.posted_at >= ?", range_begin)
        end
        if date_to.present?
          range_end = Time.zone.parse("#{date_to} 23:59:59.999999")
          scope = scope.where("teller_transactions.posted_at <= ?", range_end)
        end

        scope = scope.where("account_transactions.amount_cents >= ?", (params[:amount_min].to_f * 100).round) if params[:amount_min].present?
        scope = scope.where("account_transactions.amount_cents <= ?", (params[:amount_max].to_f * 100).round) if params[:amount_max].present?

        if params[:transaction_types].present?
          types = Array(params[:transaction_types]).compact_blank
          scope = scope.where(teller_transactions: { transaction_type: types }) if types.any?
        end

        sort_col = params[:sort].presence || "date"
        sort_dir = params[:sort_dir] == "asc" ? :asc : :desc
        if sort_col == "amount"
          scope = scope.order("account_transactions.amount_cents #{sort_dir}")
        else
          scope = scope.order("teller_transactions.posted_at #{sort_dir}")
        end

        scope.limit(500)
      end

      def apply_accounts_index_filters(scope)
        scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        scope = scope.joins(:account_owners).where(account_owners: { party_id: params[:party_id] }) if params[:party_id].present?
        if params[:q].present?
          q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)}%"
          scope = scope.left_joins(account_owners: :party).where(
            "accounts.account_number LIKE ? OR parties.display_name LIKE ?",
            q, q
          ).distinct
        end
        scope = scope.where(account_type: params[:account_type]) if params[:account_type].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope
      end
  end
end
