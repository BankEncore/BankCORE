# frozen_string_literal: true

module Admin
  class UserRolesController < BaseController
    before_action :set_user

    def create
      @user_role = @user.user_roles.build(user_role_params)
      authorize [ :admin, @user_role ]

      if @user_role.save
        redirect_to admin_user_path(@user), notice: "Role was successfully assigned."
      else
        redirect_to admin_user_path(@user), alert: @user_role.errors.full_messages.to_sentence
      end
    end

    def destroy
      @user_role = @user.user_roles.find(params[:id])
      authorize [ :admin, @user_role ]

      @user_role.destroy
      redirect_to admin_user_path(@user), notice: "Role assignment was removed."
    end

    private
      def set_user
        @user = User.find(params[:user_id])
      end

      def user_role_params
        params.require(:user_role).permit(:role_id, :branch_id, :workstation_id)
      end
  end
end
