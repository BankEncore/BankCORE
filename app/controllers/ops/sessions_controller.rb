module Ops
  class SessionsController < BaseController
    before_action :require_ops_access

    def index
      @branches = Branch.order(:code)
      @users = User.order(:display_name, :email_address)
      @workstations = Workstation.joins(:branch).order("branches.code", "workstations.code")
      @filter = default_filters.merge(filter_params.to_h.symbolize_keys)
      @sessions = scoped_sessions
        .includes(:user, :branch, :workstation, :cash_location)
        .order(opened_at: :desc)
        .limit(200)
        .to_a
      session_ids = @sessions.map(&:id)
      @transaction_counts = session_ids.any? ? TellerTransaction.where(teller_session_id: session_ids).group(:teller_session_id).count : {}
    end

    def show
      @session = TellerSession.find(params[:id])
      @transactions = @session.teller_transactions
        .where(status: "posted")
        .includes(:posting_batch, :cash_movements)
        .order(posted_at: :desc)
      @cash_in_cents = @session.cash_movements.where(direction: "in").sum(:amount_cents)
      @cash_out_cents = @session.cash_movements.where(direction: "out").sum(:amount_cents)
    end

    private
      def require_ops_access
        true
      end

      def scoped_sessions
        scope = TellerSession.all

        if filter_params[:branch_id].present?
          scope = scope.where(branch_id: filter_params[:branch_id])
        end

        if filter_params[:user_id].present?
          scope = scope.where(user_id: filter_params[:user_id])
        end

        if filter_params[:workstation_id].present?
          scope = scope.where(workstation_id: filter_params[:workstation_id])
        end

        if filter_params[:status].present? && filter_params[:status] != "all"
          scope = scope.where(status: filter_params[:status])
        end

        if filter_params[:date_from].present?
          date_from = Date.parse(filter_params[:date_from]) rescue nil
          scope = scope.where("opened_at >= ?", date_from.beginning_of_day) if date_from
        end

        if filter_params[:date_to].present?
          date_to = Date.parse(filter_params[:date_to]) rescue nil
          scope = scope.where("opened_at <= ?", date_to.end_of_day) if date_to
        end

        scope
      end

      def default_filters
        today = Date.current
        {
          date_from: today.to_s,
          date_to: today.to_s,
          status: "all"
        }
      end

      def filter_params
        permitted = params.permit(:branch_id, :user_id, :workstation_id, :status, :date_from, :date_to)
        permitted = permitted.to_h
        permitted[:date_from] = default_filters[:date_from] if permitted[:date_from].blank?
        permitted[:date_to] = default_filters[:date_to] if permitted[:date_to].blank?
        permitted[:status] = default_filters[:status] if permitted[:status].blank?
        permitted
      end
  end
end
