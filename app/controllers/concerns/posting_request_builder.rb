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
      return "amount_threshold" if posting_params[:amount_cents].to_i >= approval_amount_threshold_cents

      nil
    end

    def approval_policy_context(posting_params)
      trigger = approval_policy_trigger(posting_params)
      return {} if trigger.blank?

      {
        trigger: trigger,
        threshold_cents: approval_amount_threshold_cents,
        amount_cents: posting_params[:amount_cents].to_i,
        transaction_type: posting_params[:transaction_type].to_s
      }
    end

    def approval_amount_threshold_cents
      100_000
    end
end
