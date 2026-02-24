# frozen_string_literal: true

module Admin
  class RoleUsersController < BaseController
    before_action :set_role

    def create
      @user_role = UserRole.new(
        role: @role,
        user_id: params[:user_role][:user_id],
        branch_id: params[:user_role][:branch_id].presence,
        workstation_id: params[:user_role][:workstation_id].presence
      )
      authorize [ :admin, @user_role ]

      if @user_role.save
        redirect_to admin_role_path(@role), notice: "User was successfully assigned to role."
      else
        redirect_to admin_role_path(@role), alert: @user_role.errors.full_messages.to_sentence
      end
    end

    def destroy
      @user_role = UserRole.where(role: @role).find(params[:id])
      authorize [ :admin, @user_role ]

      @user_role.destroy
      redirect_to admin_role_path(@role), notice: "User assignment was removed."
    end

    private
      def set_role
        @role = Role.find(params[:role_id])
      end
  end
end
