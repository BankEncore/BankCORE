# frozen_string_literal: true

module Admin
  class CashLocationsController < BaseController
    before_action :set_branch, only: [ :new, :create ]
    before_action :set_cash_location, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize [ :admin, CashLocation ]
      @cash_locations = policy_scope([ :admin, CashLocation ]).includes(:branch).order(:branch_id, :location_type, :code)
      @cash_locations = @cash_locations.where(branch_id: params[:branch_id]) if params[:branch_id].present?
    end

    def show
      authorize [ :admin, @cash_location ]
      @cash_location_assignments = @cash_location.cash_location_assignments
        .includes(:teller_session)
        .order(assigned_at: :desc)
        .limit(50)
    end

    def new
      @cash_location = @branch.cash_locations.build
      authorize [ :admin, @cash_location ]
    end

    def create
      @cash_location = @branch.cash_locations.build(cash_location_params)
      authorize [ :admin, @cash_location ]

      if @cash_location.save
        redirect_to admin_branch_path(@branch), notice: "Cash location was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [ :admin, @cash_location ]
    end

    def update
      authorize [ :admin, @cash_location ]

      if @cash_location.update(cash_location_params)
        redirect_to admin_cash_location_path(@cash_location), notice: "Cash location was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize [ :admin, @cash_location ]

      branch = @cash_location.branch
      if @cash_location.destroy
        redirect_to admin_branch_path(branch), notice: "Cash location was successfully deleted."
      else
        redirect_to admin_cash_location_path(@cash_location), alert: "Cash location could not be deleted."
      end
    end

    private
      def set_branch
        @branch = Branch.find(params[:branch_id])
      end

      def set_cash_location
        @cash_location = CashLocation.find(params[:id])
      end

      def cash_location_params
        params.require(:cash_location).permit(:code, :name, :location_type, :active)
      end
  end
end
