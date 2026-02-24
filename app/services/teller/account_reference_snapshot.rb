module Teller
  class AccountReferenceSnapshot
    def initialize(reference:)
      @reference = reference.to_s.strip
    end

    def call
      return { ok: false, error: "Account reference is required" } if reference.blank?

      transactions = resolve_transactions_scope
      debit_total = transactions.where(direction: "debit").sum(:amount_cents)
      credit_total = transactions.where(direction: "credit").sum(:amount_cents)
      latest_transaction = transactions.order(created_at: :desc).first
      computed_balance = credit_total - debit_total

      account = Account.find_by(account_number: reference)
      primary_owner_name = account&.primary_owner&.display_name.presence

      {
        ok: true,
        reference: reference,
        account_id: account&.id,
        account_exists: account.present?,
        found: transactions.exists?,
        status: transactions.exists? ? "Active" : "No activity",
        ledger_balance_cents: latest_transaction&.running_balance_cents || computed_balance,
        available_balance_cents: latest_transaction&.running_balance_cents || computed_balance,
        total_debits_cents: debit_total,
        total_credits_cents: credit_total,
        last_posted_at: latest_transaction&.created_at&.iso8601,
        primary_owner_name: primary_owner_name,
        alerts: build_alerts(
          found: transactions.exists?,
          computed_balance: computed_balance
        ),
        restrictions: build_restrictions
      }
    end

    private
      attr_reader :reference

      def resolve_transactions_scope
        account = Account.find_by(account_number: reference)
        if account
          AccountTransaction.where(account_id: account.id)
        else
          AccountTransaction.where(account_reference: reference)
        end
      end

      def build_alerts(found:, computed_balance:)
        alerts = []
        alerts << "No transaction history for this reference" unless found
        alerts << "Account balance is negative" if computed_balance.negative?
        alerts
      end

      def build_restrictions
        restrictions = []
        restrictions << "Cash location controlled account" if reference.start_with?("cash:")
        restrictions << "Check item reference requires verification" if reference.start_with?("check:")
        restrictions
      end
  end
end
