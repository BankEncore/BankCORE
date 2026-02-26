module Teller
  class AccountReferencesController < BaseController
    include PostingPrerequisites

    before_action :ensure_authorized
    before_action :require_posting_context!

    def show
      snapshot = ::Teller::AccountReferenceSnapshot.new(reference: params[:reference]).call

      if snapshot[:ok]
        render json: snapshot
      else
        render json: snapshot, status: :unprocessable_entity
      end
    end

    def history
      reference = params[:reference].to_s.strip
      if reference.blank?
        render json: { ok: false, error: "Account reference is required" }, status: :unprocessable_entity
        return
      end

      limit = [ params[:limit].to_i, 50 ].reject(&:zero?).min || 10

      entries = resolve_history_scope(reference)
        .includes(:teller_transaction)
        .order(created_at: :desc)
        .limit(limit)
        .map do |transaction|
          {
            id: transaction.id,
            direction: transaction.direction,
            amount_cents: transaction.amount_cents,
            signed_amount_cents: transaction.direction == "credit" ? transaction.amount_cents : -transaction.amount_cents,
            transaction_type: transaction.teller_transaction.transaction_type,
            request_id: transaction.teller_transaction.request_id,
            posted_at: transaction.teller_transaction.posted_at.iso8601,
            description: transaction.description
          }
        end

      render json: {
        ok: true,
        reference: reference,
        entries: entries
      }
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end

      def resolve_history_scope(reference)
        account = Account.find_by(account_number: reference)
        if account
          AccountTransaction.where(account_id: account.id)
        else
          AccountTransaction.where(account_reference: reference)
        end
      end
  end
end
