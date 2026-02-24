# frozen_string_literal: true

module Admin
  class WorkstationsController < BaseController
    before_action :set_branch, only: [ :new, :create ]
    before_action :set_workstation, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize [ :admin, Workstation ]
      @workstations = policy_scope([ :admin, Workstation ]).includes(:branch).order(:branch_id, :code)
      @workstations = @workstations.where(branch_id: params[:branch_id]) if params[:branch_id].present?
    end

    def show
      authorize [ :admin, @workstation ]
    end

    def new
      @workstation = @branch.workstations.build
      authorize [ :admin, @workstation ]
    end

    def create
      @workstation = @branch.workstations.build(workstation_params)
      authorize [ :admin, @workstation ]

      if @workstation.save
        redirect_to admin_branch_path(@branch), notice: "Workstation was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [ :admin, @workstation ]
    end

    def update
      authorize [ :admin, @workstation ]

      if @workstation.update(workstation_params)
        redirect_to admin_workstation_path(@workstation), notice: "Workstation was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize [ :admin, @workstation ]

      branch = @workstation.branch
      if @workstation.destroy
        redirect_to admin_branch_path(branch), notice: "Workstation was successfully deleted."
      else
        redirect_to admin_workstation_path(@workstation), alert: "Workstation could not be deleted."
      end
    end

    private
      def set_branch
        @branch = Branch.find(params[:branch_id])
      end

      def set_workstation
        @workstation = Workstation.find(params[:id])
      end

      def workstation_params
        params.require(:workstation).permit(:code, :name)
      end
  end
end
