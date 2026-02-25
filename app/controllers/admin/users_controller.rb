# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize [ :admin, User ]
      @users = policy_scope([ :admin, User ]).order(:email_address)
    end

    def show
      authorize [ :admin, @user ]
      @user_roles = @user.user_roles.includes(:role, :branch, :workstation).order("roles.key")
    end

    def new
      @user = User.new
      authorize [ :admin, @user ]
    end

    def create
      @user = User.new(user_params)
      authorize [ :admin, @user ]

      if @user.save
        redirect_to admin_user_path(@user), notice: "User was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [ :admin, @user ]
    end

    def update
      authorize [ :admin, @user ]

      if @user.update(user_update_params)
        redirect_to admin_user_path(@user), notice: "User was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize [ :admin, @user ]

      if @user.destroy
        redirect_to admin_users_path, notice: "User was successfully deleted."
      else
        redirect_to admin_user_path(@user), alert: "User could not be deleted."
      end
    end

    private
      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:email_address, :teller_number, :first_name, :last_name, :display_name, :default_workspace, :pin, :password, :password_confirmation)
      end

      def user_update_params
        p = params.require(:user).permit(:email_address, :teller_number, :first_name, :last_name, :display_name, :default_workspace, :pin, :password, :password_confirmation)
        p.delete(:password) if p[:password].blank?
        p.delete(:password_confirmation) if p[:password_confirmation].blank?
        p.delete(:pin) if p[:pin].blank?
        p
      end
  end
end
