# frozen_string_literal: true

module Admin
  class RolesController < BaseController
    before_action :set_role, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize [ :admin, Role ]
      @roles = policy_scope([ :admin, Role ]).order(:key)
    end

    def show
      authorize [ :admin, @role ]
      @user_roles = UserRole.where(role: @role).includes(:user, :branch, :workstation).order("users.email_address")
    end

    def new
      @role = Role.new
      authorize [ :admin, @role ]
      @permissions = Permission.order(:key)
    end

    def create
      @role = Role.new(role_params)
      authorize [ :admin, @role ]

      if @role.save
        update_role_permissions if params[:permission_ids].present?
        redirect_to admin_role_path(@role), notice: "Role was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [ :admin, @role ]
      @permissions = Permission.order(:key)
    end

    def update
      authorize [ :admin, @role ]

      if @role.update(role_params)
        update_role_permissions
        redirect_to admin_role_path(@role), notice: "Role was successfully updated."
      else
        @permissions = Permission.order(:key)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize [ :admin, @role ]

      if @role.destroy
        redirect_to admin_roles_path, notice: "Role was successfully deleted."
      else
        redirect_to admin_role_path(@role), alert: "Role could not be deleted."
      end
    end

    private
      def set_role
        @role = Role.find(params[:id])
      end

      def role_params
        params.require(:role).permit(:key, :name)
      end

      def update_role_permissions
        permission_ids = Array(params[:permission_ids]).reject(&:blank?).map(&:to_i)
        @role.role_permissions.destroy_all
        permission_ids.each do |permission_id|
          @role.role_permissions.create!(permission_id: permission_id)
        end
      end
  end
end
