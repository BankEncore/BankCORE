# frozen_string_literal: true

module Teller
  class AccountsController < BaseController
    before_action :set_account, only: [ :show, :edit, :update ]
    before_action :set_branch_for_new, only: [ :new, :create ]
    before_action :ensure_authorized

    def index
      scope = Account.includes(:branch, :account_owners, :parties)
      scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?
      scope = scope.joins(:account_owners).where(account_owners: { party_id: params[:party_id] }) if params[:party_id].present?
      @accounts = scope.order(account_number: :asc).limit(100)
    end

    def show
      @account_transactions = @account.account_transactions
        .includes(teller_transaction: :posting_batch)
        .order(created_at: :desc)
        .limit(50)
    end

    def edit
    end

    def update
      if @account.update(account_update_params)
        redirect_to teller_account_path(@account), notice: "Account updated."
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
          redirect_to teller_account_path(@account), notice: "Account created."
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
        redirect_to(teller_context_path, alert: "Select branch first.") and return if @branch.blank?
      end

      def ensure_authorized
        authorize([ :teller, @account || Account ], policy_class: Teller::AccountPolicy)
      end

      def account_params
        params.require(:account).permit(:account_number, :account_type, :branch_id, :status, :opened_on, :closed_on)
      end

      def account_update_params
        params.require(:account).permit(:account_type, :status, :opened_on, :closed_on)
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
  end
end
