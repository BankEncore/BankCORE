# frozen_string_literal: true

module Teller
  class PartiesController < BaseController
    before_action :set_party, only: [ :show, :edit, :update ]
    before_action :ensure_authorized

    def index
      @parties = Party.where(is_active: true).order(display_name: :asc).limit(100)
      @parties = @parties.where(party_kind: params[:party_kind]) if params[:party_kind].present?
      @parties = @parties.where(relationship_kind: params[:relationship_kind]) if params[:relationship_kind].present?
    end

    def show
    end

    def new
      @party = Party.new(party_kind: params[:party_kind].presence || "individual", relationship_kind: params[:relationship_kind].presence || "customer")
    end

    def create
      @party = Party.new(party_params)
      if @party.save
        begin
          create_party_detail
          redirect_to teller_party_path(@party), notice: "Party created."
        rescue ActiveRecord::RecordInvalid => e
          @party.errors.add(:base, e.record.errors.full_messages.join(", "))
          render :new, status: :unprocessable_entity
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @party.update(party_params)
        update_party_detail
        redirect_to teller_party_path(@party), notice: "Party updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

      def set_party
        @party = Party.find(params[:id])
      end

      def ensure_authorized
        authorize([ :teller, @party || Party ], policy_class: Teller::PartyPolicy)
      end

      def party_params
        params.require(:party).permit(:party_kind, :relationship_kind, :display_name, :is_active, :tax_id, :street_address, :city, :state, :zip_code, :phone, :email)
      end

      def create_party_detail
        if @party.individual?
          @party.create_party_individual!(individual_params)
        elsif @party.organization?
          @party.create_party_organization!(organization_params)
        end
      end

      def update_party_detail
        if @party.individual?
          @party.party_individual&.update!(individual_params) || @party.create_party_individual!(individual_params)
        elsif @party.organization?
          @party.party_organization&.update!(organization_params) || @party.create_party_organization!(organization_params)
        end
      end

      def individual_params
        params.require(:party).permit(:first_name, :last_name, :dob, :govt_id_type, :govt_id).slice(:first_name, :last_name, :dob, :govt_id_type, :govt_id).to_h.compact
      end

      def organization_params
        params.require(:party).permit(:legal_name, :dba_name).slice(:legal_name, :dba_name).to_h.compact
      end
  end
end
