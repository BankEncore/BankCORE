# frozen_string_literal: true

module Admin
  class MiscReceiptTypesController < BaseController
    before_action :set_misc_receipt_type, only: [ :edit, :update ]

    def index
      authorize [ :admin, MiscReceiptType ]
      @misc_receipt_types = policy_scope([ :admin, MiscReceiptType ]).ordered
    end

    def new
      @misc_receipt_type = MiscReceiptType.new
      authorize [ :admin, @misc_receipt_type ]
    end

    def create
      @misc_receipt_type = MiscReceiptType.new(misc_receipt_type_params)
      authorize [ :admin, @misc_receipt_type ]

      if @misc_receipt_type.save
        redirect_to admin_misc_receipt_types_path, notice: "Misc receipt type was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [ :admin, @misc_receipt_type ]
    end

    def update
      authorize [ :admin, @misc_receipt_type ]

      if @misc_receipt_type.update(misc_receipt_type_params)
        redirect_to admin_misc_receipt_types_path, notice: "Misc receipt type was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def set_misc_receipt_type
        @misc_receipt_type = MiscReceiptType.find(params[:id])
      end

      def misc_receipt_type_params
        params.require(:misc_receipt_type).permit(
          :code,
          :label,
          :income_account_reference,
          :default_amount_cents,
          :memo_required,
          :is_active,
          :display_order
        )
      end
  end
end
