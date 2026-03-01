# frozen_string_literal: true

module Admin
  class BillPayeesController < BaseController
    before_action :set_bill_payee, only: [ :edit, :update ]

    def index
      authorize [ :admin, BillPayee ]
      @bill_payees = policy_scope([ :admin, BillPayee ]).ordered
    end

    def new
      @bill_payee = BillPayee.new
      authorize [ :admin, @bill_payee ]
    end

    def create
      @bill_payee = BillPayee.new(bill_payee_params)
      authorize [ :admin, @bill_payee ]

      if @bill_payee.save
        redirect_to admin_bill_payees_path, notice: "Bill payee was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [ :admin, @bill_payee ]
    end

    def update
      authorize [ :admin, @bill_payee ]

      if @bill_payee.update(bill_payee_params)
        redirect_to admin_bill_payees_path, notice: "Bill payee was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def set_bill_payee
        @bill_payee = BillPayee.find(params[:id])
      end

      def bill_payee_params
        params.require(:bill_payee).permit(
          :code,
          :name,
          :liability_account_reference,
          :default_fee_amount_cents,
          :memo_required,
          :is_active,
          :display_order
        )
      end
  end
end
