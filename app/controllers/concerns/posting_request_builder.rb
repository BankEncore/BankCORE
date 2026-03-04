module PostingRequestBuilder
  extend ActiveSupport::Concern

  private
    def posting_metadata(posting_params)
      build_recipe(posting_params).posting_metadata
    end

    def normalized_entries(posting_params)
      build_recipe(posting_params).normalized_entries
    end

    def build_recipe(posting_params)
      Posting::RecipeBuilder.new(
        posting_params: posting_params,
        default_cash_account_reference: default_cash_account_reference
      )
    end

    def default_cash_account_reference
      return "cash:unassigned" if current_teller_session&.cash_location.blank?

      "cash:#{current_teller_session.cash_location.code}"
    end

    def approval_required?(posting_params)
      approval_policy_trigger(posting_params).present?
    end

    def approval_policy_trigger(posting_params)
      result = approval_threshold_check(posting_params)
      result&.dig(:policy_trigger)
    end

    def approval_policy_context(posting_params)
      result = approval_threshold_check(posting_params)
      return {} if result.blank?

      {
        trigger: result[:policy_trigger],
        threshold_cents: result[:threshold_cents],
        amount_cents: result[:amount_cents],
        transaction_type: posting_params[:transaction_type].to_s,
        trigger_key: result[:trigger_key],
        context: result[:context]
      }.compact
    end

    def approval_threshold_check(posting_params)
      entries = normalized_entries(posting_params)
      threshold_result = Posting::ApprovalThresholdChecker.call(
        posting_params: posting_params,
        entries: entries,
        default_cash_account_reference: default_cash_account_reference
      )
      return threshold_result if threshold_result.present?

      Posting::FeeOverrideChecker.call(posting_params: posting_params)
    end
end
