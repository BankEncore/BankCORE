module Posting
  class SessionHandoffVarianceService
    def initialize(teller_session:, opening_cents:, previous_closing_cents:)
      @teller_session = teller_session
      @opening_cents = opening_cents.to_i
      @previous_closing_cents = previous_closing_cents.to_i
    end

    def call
      variance_cents = @opening_cents - @previous_closing_cents
      return if variance_cents.zero?
      return if @teller_session.cash_location.blank?

      amount_cents = variance_cents.abs
      drawer_reference = "cash:#{@teller_session.cash_location.code}"

      legs = if variance_cents.negative?
        [
          { side: "debit", account_reference: "expense:cash_short", amount_cents: amount_cents },
          { side: "credit", account_reference: drawer_reference, amount_cents: amount_cents }
        ]
      else
        [
          { side: "debit", account_reference: drawer_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: "income:cash_over", amount_cents: amount_cents }
        ]
      end

      Posting::Engine.new(
        user: @teller_session.user,
        teller_session: @teller_session,
        branch: @teller_session.branch,
        workstation: @teller_session.workstation,
        request_id: "session-handoff-#{@teller_session.id}",
        transaction_type: "session_handoff_variance",
        amount_cents: amount_cents,
        entries: legs,
        metadata: {
          opening_cents: @opening_cents,
          previous_closing_cents: @previous_closing_cents
        },
        currency: "USD"
      ).call
    end
  end
end
