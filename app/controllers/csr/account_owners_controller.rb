# frozen_string_literal: true

module Csr
  class AccountOwnersController < BaseController
    before_action :set_account
    before_action :set_account_owner, only: [ :destroy, :update ]
    before_action :ensure_authorized

    def create
      @account_owner = @account.account_owners.build(account_owner_params)
      if @account_owner.save
        redirect_to csr_account_path(@account), notice: "Owner added."
      else
        redirect_to csr_account_path(@account), alert: @account_owner.errors.full_messages.to_sentence
      end
    end

    def destroy
      if @account_owner.destroy
        redirect_to csr_account_path(@account), notice: "Owner removed."
      else
        redirect_to csr_account_path(@account), alert: @account_owner.errors.full_messages.to_sentence
      end
    end

    def update
      if @account_owner.update(account_owner_update_params)
        redirect_to csr_account_path(@account), notice: "Primary owner updated."
      else
        redirect_to csr_account_path(@account), alert: @account_owner.errors.full_messages.to_sentence
      end
    end

    private

      def set_account
        @account = Account.find(params[:account_id])
      end

      def set_account_owner
        @account_owner = @account.account_owners.find(params[:id])
      end

      def ensure_authorized
        authorize([ :csr, @account ], :update?, policy_class: Csr::AccountPolicy)
      end

      def account_owner_params
        permitted = params.require(:account_owner).permit(:party_id, :is_primary)
        permitted[:is_primary] = ActiveModel::Type::Boolean.new.cast(permitted[:is_primary]) if permitted.key?(:is_primary)
        permitted[:is_primary] = false if permitted[:is_primary].nil?
        permitted
      end

      def account_owner_update_params
        permitted = params.require(:account_owner).permit(:is_primary)
        permitted[:is_primary] = ActiveModel::Type::Boolean.new.cast(permitted[:is_primary]) if permitted.key?(:is_primary)
        permitted
      end
  end
end
