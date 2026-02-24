# frozen_string_literal: true

module Admin
  class BranchesController < BaseController
    before_action :set_branch, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize [ :admin, Branch ]
      @branches = policy_scope([ :admin, Branch ]).order(:code)
    end

    def show
      authorize [ :admin, @branch ]
      @workstations = @branch.workstations.order(:code)
      @cash_locations = @branch.cash_locations.order(:location_type, :code)
    end

    def new
      @branch = Branch.new
      authorize [ :admin, @branch ]
    end

    def create
      @branch = Branch.new(branch_params)
      authorize [ :admin, @branch ]

      if @branch.save
        redirect_to admin_branch_path(@branch), notice: "Branch was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [ :admin, @branch ]
    end

    def update
      authorize [ :admin, @branch ]

      if @branch.update(branch_params)
        redirect_to admin_branch_path(@branch), notice: "Branch was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize [ :admin, @branch ]

      if @branch.destroy
        redirect_to admin_branches_path, notice: "Branch was successfully deleted."
      else
        redirect_to admin_branch_path(@branch), alert: "Branch could not be deleted."
      end
    end

    private
      def set_branch
        @branch = Branch.find(params[:id])
      end

      def branch_params
        params.require(:branch).permit(:code, :name)
      end
  end
end
