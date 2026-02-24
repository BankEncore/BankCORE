# frozen_string_literal: true

module Admin
  class CashLocationAssignmentsController < BaseController
    before_action :set_cash_location_assignment, only: [ :show ]

    def index
      authorize [ :admin, CashLocationAssignment ]
      @cash_location_assignments = policy_scope([ :admin, CashLocationAssignment ])
        .includes(:teller_session, :cash_location)
        .order(assigned_at: :desc)
        .limit(100)

      @cash_location_assignments = @cash_location_assignments.joins(:cash_location).where(cash_locations: { branch_id: params[:branch_id] }) if params[:branch_id].present?
      @cash_location_assignments = @cash_location_assignments.where(cash_location_id: params[:cash_location_id]) if params[:cash_location_id].present?
      @cash_location_assignments = @cash_location_assignments.where(teller_session_id: params[:teller_session_id]) if params[:teller_session_id].present?
      @cash_location_assignments = @cash_location_assignments.where("assigned_at >= ?", params[:from_date]) if params[:from_date].present?
      @cash_location_assignments = @cash_location_assignments.where("assigned_at <= ?", params[:to_date]) if params[:to_date].present?
    end

    def show
      authorize [ :admin, @cash_location_assignment ]
    end

    private
      def set_cash_location_assignment
        @cash_location_assignment = CashLocationAssignment.find(params[:id])
      end
  end
end
