module Posting
  class Engine
    class Error < StandardError; end

    attr_reader :request

    def initialize(user:, teller_session:, branch:, workstation:, request_id:, transaction_type:, amount_cents:, entries:, metadata: {}, currency: "USD")
      @request = build_request(
        user: user,
        teller_session: teller_session,
        branch: branch,
        workstation: workstation,
        request_id: request_id,
        transaction_type: transaction_type,
        amount_cents: amount_cents,
        entries: entries,
        metadata: metadata,
        currency: currency
      )
    end

    def call
      existing_batch = PostingBatch.find_by(request_id: request.fetch(:request_id))
      return existing_batch if existing_batch.present?

      validate
      apply_policy
      legs = generate_legs
      balance_check(legs)
      commit(legs)
    rescue ActiveRecord::RecordNotUnique
      PostingBatch.find_by!(request_id: request.fetch(:request_id))
    end

    private
      def build_request(user:, teller_session:, branch:, workstation:, request_id:, transaction_type:, amount_cents:, entries:, metadata:, currency:)
        {
          user: user,
          teller_session: teller_session,
          branch: branch,
          workstation: workstation,
          request_id: request_id.to_s,
          transaction_type: transaction_type.to_s,
          amount_cents: amount_cents.to_i,
          metadata: metadata.presence || {},
          currency: currency.to_s,
          entries: Array(entries).map.with_index do |entry, index|
            {
              side: entry.fetch(:side).to_s,
              account_reference: entry.fetch(:account_reference).to_s,
              amount_cents: entry.fetch(:amount_cents).to_i,
              position: index
            }
          end
        }
      end

      def validate
        required = %i[user teller_session branch workstation request_id transaction_type amount_cents currency entries]
        required.each do |key|
          value = request[key]
          raise Error, "#{key} is required" if value.blank?
        end

        raise Error, "amount_cents must be greater than zero" unless request[:amount_cents].positive?
        raise Error, "entries must be present" if request[:entries].empty?
      end

      def apply_policy
        teller_session = request.fetch(:teller_session)

        raise Error, "teller session must be open" unless teller_session.open?
        raise Error, "drawer must be assigned" if drawer_required? && teller_session.cash_location.blank?
      end

      def drawer_required?
        cash_affecting_transaction_type? || cash_legs_present?
      end

      def cash_affecting_transaction_type?
        %w[deposit withdrawal check_cashing].include?(request.fetch(:transaction_type))
      end

      def cash_legs_present?
        request.fetch(:entries).any? { |entry| entry.fetch(:account_reference).start_with?("cash:") }
      end

      def generate_legs
        request.fetch(:entries)
      end

      def balance_check(legs)
        debit_total = legs.select { |leg| leg[:side] == "debit" }.sum { |leg| leg[:amount_cents] }
        credit_total = legs.select { |leg| leg[:side] == "credit" }.sum { |leg| leg[:amount_cents] }

        raise Error, "posting legs are unbalanced" unless debit_total == credit_total
      end

      def commit(legs)
        ActiveRecord::Base.transaction do
          teller_transaction = TellerTransaction.create!(
            user: request.fetch(:user),
            teller_session: request.fetch(:teller_session),
            branch: request.fetch(:branch),
            workstation: request.fetch(:workstation),
            request_id: request.fetch(:request_id),
            transaction_type: request.fetch(:transaction_type),
            currency: request.fetch(:currency),
            amount_cents: request.fetch(:amount_cents),
            status: "posted",
            posted_at: Time.current
          )

          posting_batch = PostingBatch.create!(
            teller_transaction: teller_transaction,
            request_id: request.fetch(:request_id),
            currency: request.fetch(:currency),
            status: "committed",
            committed_at: Time.current,
            metadata: request.fetch(:metadata)
          )

          legs.each do |leg|
            PostingLeg.create!(
              posting_batch: posting_batch,
              side: leg.fetch(:side),
              account_reference: leg.fetch(:account_reference),
              amount_cents: leg.fetch(:amount_cents),
              position: leg.fetch(:position)
            )

            AccountTransaction.create!(
              teller_transaction: teller_transaction,
              posting_batch: posting_batch,
              account_reference: leg.fetch(:account_reference),
              direction: leg.fetch(:side),
              amount_cents: leg.fetch(:amount_cents)
            )
          end

          create_cash_movement!(teller_transaction, legs)

          posting_batch
        end
      end

      def create_cash_movement!(teller_transaction, legs)
        direction = case request.fetch(:transaction_type)
        when "deposit"
          "in"
        when "withdrawal", "check_cashing"
          "out"
        else
          nil
        end

        return if direction.blank?

        cash_account_prefix = "cash:"
        cash_legs = legs.select { |leg| leg.fetch(:account_reference).start_with?(cash_account_prefix) }
        cash_amount_cents = case request.fetch(:transaction_type)
        when "deposit"
          cash_legs.select { |leg| leg.fetch(:side) == "debit" }.sum { |leg| leg.fetch(:amount_cents) }
        when "withdrawal", "check_cashing"
          cash_legs.select { |leg| leg.fetch(:side) == "credit" }.sum { |leg| leg.fetch(:amount_cents) }
        else
          0
        end

        return unless cash_amount_cents.positive?

        CashMovement.create!(
          teller_transaction: teller_transaction,
          teller_session: request.fetch(:teller_session),
          cash_location: request.fetch(:teller_session).cash_location,
          direction: direction,
          amount_cents: cash_amount_cents
        )
      end
  end
end
