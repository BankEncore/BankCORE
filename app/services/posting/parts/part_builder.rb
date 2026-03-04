# frozen_string_literal: true

module Posting
  module Parts
    class PartBuilder
      class ValidationError < StandardError; end

      def self.build_entries(flow_type:, **params)
        new(flow_type: flow_type, **params).build_entries
      end

      def initialize(flow_type:, **params)
        @flow_type = flow_type.to_s
        @params = params
      end

      def build_entries
        flow.build_entries
      end

      private

      attr_reader :flow_type, :params

      def flow
        @flow ||= case flow_type
        when "check_cashing"
          parts = TransactionParts.new(
            check_items: params.fetch(:check_items),
            fee_cents: params.fetch(:fee_cents, 0),
            cash_account_reference: params.fetch(:cash_account_reference),
            fee_income_account_reference: params[:fee_income_account_reference]
          )
          Flows::CheckCashingFlow.new(transaction_parts: parts)
        when "withdrawal"
          Flows::WithdrawalFlow.new(
            amount_cents: params.fetch(:amount_cents),
            fee_cents: params.fetch(:fee_cents, 0),
            primary_account_reference: params.fetch(:primary_account_reference),
            cash_account_reference: params.fetch(:cash_account_reference),
            fee_income_account_reference: params[:fee_income_account_reference]
          )
        when "transfer"
          Flows::TransferFlow.new(
            amount_cents: params.fetch(:amount_cents),
            fee_cents: params.fetch(:fee_cents, 0),
            primary_account_reference: params.fetch(:primary_account_reference),
            counterparty_account_reference: params.fetch(:counterparty_account_reference),
            fee_income_account_reference: params[:fee_income_account_reference]
          )
        when "deposit"
          Flows::DepositFlow.new(
            amount_cents: params.fetch(:amount_cents, 0),
            cash_back_cents: params.fetch(:cash_back_cents, 0),
            fee_cents: params.fetch(:fee_cents, 0),
            check_items: params.fetch(:check_items, []),
            primary_account_reference: params.fetch(:primary_account_reference),
            cash_account_reference: params.fetch(:cash_account_reference),
            fee_income_account_reference: params[:fee_income_account_reference]
          )
        when "vault_transfer"
          Flows::VaultTransferFlow.new(
            amount_cents: params.fetch(:amount_cents),
            source_cash_account_reference: params.fetch(:source_cash_account_reference),
            destination_cash_account_reference: params.fetch(:destination_cash_account_reference)
          )
        when "misc_receipt"
          Flows::MiscReceiptFlow.new(
            amount_cents: params.fetch(:amount_cents),
            misc_cash_cents: params.fetch(:misc_cash_cents, 0),
            misc_account_cents: params.fetch(:misc_account_cents, 0),
            check_items: params.fetch(:check_items, []),
            primary_account_reference: params[:primary_account_reference].to_s,
            cash_account_reference: params.fetch(:cash_account_reference),
            income_account_reference: params.fetch(:income_account_reference)
          )
        when "draft"
          Flows::DraftFlow.new(
            draft_amount_cents: params.fetch(:draft_amount_cents),
            draft_fee_cents: params.fetch(:draft_fee_cents, 0),
            draft_cash_cents: params.fetch(:draft_cash_cents, 0),
            draft_account_cents: params.fetch(:draft_account_cents, 0),
            check_items: params.fetch(:check_items, []),
            primary_account_reference: params[:primary_account_reference].to_s,
            cash_account_reference: params.fetch(:cash_account_reference),
            draft_liability_account_reference: params.fetch(:draft_liability_account_reference),
            draft_fee_income_account_reference: params[:draft_fee_income_account_reference]
          )
        when "bill_payment"
          Flows::BillPaymentFlow.new(
            payment_cents: params.fetch(:payment_cents),
            fee_cents: params.fetch(:fee_cents, 0),
            bill_payment_cash_cents: params.fetch(:bill_payment_cash_cents, 0),
            bill_payment_account_cents: params.fetch(:bill_payment_account_cents, 0),
            check_items: params.fetch(:check_items, []),
            primary_account_reference: params[:primary_account_reference].to_s,
            cash_account_reference: params.fetch(:cash_account_reference),
            liability_account_reference: params.fetch(:liability_account_reference),
            fee_income_account_reference: params[:fee_income_account_reference]
          )
        else
          raise ArgumentError, "Unknown flow type: #{flow_type}"
        end
      end
    end
  end
end
