# frozen_string_literal: true

module Ops
  class LargeCashController < BaseController
    before_action :require_ops_access

    def index
      @date = parse_date_param.presence || Date.current
      @party_id = params[:party_id].presence
      @threshold_cents = parse_threshold_param

      @records = load_records
      @selected_party = Party.find_by(id: @party_id) if @party_id.present?
    end

    private
      def require_ops_access
        true
      end

      def parse_date_param
        return nil if params[:date].blank?

        Date.parse(params[:date].to_s)
      rescue ArgumentError
        nil
      end

      def parse_threshold_param
        raw = params[:threshold].presence
        return PartyCashDailyTotal::DEFAULT_THRESHOLD_CENTS if raw.blank?

        cents = (raw.to_f * 100).round
        cents.positive? ? cents : PartyCashDailyTotal::DEFAULT_THRESHOLD_CENTS
      end

      def load_records
        scope = PartyCashDailyTotal
          .for_date(@date)
          .includes(:party)
          .order(Arel.sql("cash_in_cents + cash_out_cents DESC"))

        if @party_id.present?
          scope = scope.where(party_id: @party_id)
        else
          scope = scope.exceeding_threshold(threshold_cents: @threshold_cents)
        end

        scope.to_a
      end
  end
end
