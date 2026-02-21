module PostingPrerequisites
  extend ActiveSupport::Concern

  private
    def require_open_teller_session!
      return if current_teller_session.present?

      redirect_to new_teller_teller_session_path, alert: "Open a teller session before posting transactions."
    end

    def require_assigned_drawer!
      return if current_teller_session&.cash_location.present?

      redirect_to new_teller_teller_session_path, alert: "Assign a drawer before posting transactions."
    end

    def require_posting_context!
      require_open_teller_session!
      return if performed?

      require_assigned_drawer! if drawer_required_for_request?
    end

    def drawer_required_for_request?
      transaction_type = params[:transaction_type].to_s.presence || inferred_transaction_type
      %w[deposit withdrawal check_cashing].include?(transaction_type)
    end

    def inferred_transaction_type
      case controller_path
      when "teller/deposits"
        "deposit"
      when "teller/withdrawals"
        "withdrawal"
      when "teller/transfers"
        "transfer"
      when "teller/check_cashings"
        "check_cashing"
      when "teller/transaction_pages"
        case action_name
        when "deposit"
          "deposit"
        when "withdrawal"
          "withdrawal"
        when "transfer"
          "transfer"
        when "check_cashing"
          "check_cashing"
        end
      end
    end
end
