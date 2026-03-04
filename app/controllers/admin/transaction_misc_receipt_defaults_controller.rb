# frozen_string_literal: true

module Admin
  class TransactionMiscReceiptDefaultsController < BaseController
    before_action :set_transaction_misc_receipt_default, only: [ :edit, :update, :destroy ]

    def index
      authorize [ :admin, TransactionMiscReceiptDefault ]
      @transaction_misc_receipt_defaults = policy_scope([ :admin, TransactionMiscReceiptDefault ])
        .includes(:misc_receipt_type)
        .ordered
    end

    def new
      @transaction_misc_receipt_default = TransactionMiscReceiptDefault.new
      authorize [ :admin, @transaction_misc_receipt_default ]
    end

    def create
      @transaction_misc_receipt_default = TransactionMiscReceiptDefault.new(transaction_misc_receipt_default_params)
      authorize [ :admin, @transaction_misc_receipt_default ]

      if @transaction_misc_receipt_default.save
        redirect_to admin_transaction_misc_receipt_defaults_path, notice: "Linked fee was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [ :admin, @transaction_misc_receipt_default ]
    end

    def update
      authorize [ :admin, @transaction_misc_receipt_default ]

      if @transaction_misc_receipt_default.update(transaction_misc_receipt_default_params)
        redirect_to admin_transaction_misc_receipt_defaults_path, notice: "Linked fee was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize [ :admin, @transaction_misc_receipt_default ]

      if @transaction_misc_receipt_default.destroy
        redirect_to admin_transaction_misc_receipt_defaults_path, notice: "Linked fee was successfully removed."
      else
        redirect_to admin_transaction_misc_receipt_defaults_path, alert: "Linked fee could not be removed."
      end
    end

    private
      def set_transaction_misc_receipt_default
        @transaction_misc_receipt_default = TransactionMiscReceiptDefault.find(params[:id])
      end

      def transaction_misc_receipt_default_params
        params.require(:transaction_misc_receipt_default).permit(
          :transaction_type,
          :misc_receipt_type_id,
          :display_order,
          :mandatory,
          :override_policy,
          :default_amount_cents
        )
      end
  end
end
