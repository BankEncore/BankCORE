# frozen_string_literal: true

module Teller
  class PartiesController < BaseController
    before_action :set_party, only: [ :show, :edit, :update, :accounts ]
    before_action :ensure_authorized

    def index
      scope = Party.where(is_active: true).left_joins(:party_individual, :account_owners, :accounts).distinct
      scope = apply_parties_search(scope)
      scope = scope.where(party_kind: params[:party_kind]) if params[:party_kind].present?
      scope = scope.where(relationship_kind: params[:relationship_kind]) if params[:relationship_kind].present?
      scope = scope.reorder("parties.display_name ASC")
      per_page = [ 10, 25, 50, 100 ].include?(params[:per_page].to_i) ? params[:per_page].to_i : 10
      @pagy, @parties = pagy(:offset, scope, limit: per_page)
    end

    def search
      scope = Party.where(is_active: true, party_kind: "individual").includes(:party_individual).order(display_name: :asc).limit(20)
      if params[:q].present?
        q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)}%"
        scope = scope.where("display_name LIKE ? OR phone LIKE ?", q, q)
      end
      parties = scope.map do |p|
        pi = p.party_individual
        raw_type = pi&.govt_id_type
        govt_id_type = raw_type == "driver_license" ? "drivers_license" : raw_type.presence
        govt_id = pi&.govt_id
        {
          id: p.id,
          display_name: p.display_name.presence || "Party ##{p.id}",
          relationship_kind: p.relationship_kind,
          address: [ p.street_address, p.city, [ p.state, p.zip_code ].compact_blank.join(" ") ].compact_blank.join(", ").presence,
          phone: p.phone,
          govt_id_type: govt_id_type,
          govt_id: govt_id.presence
        }
      end
      render json: parties
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
          return_to = params[:return_to].presence
          if return_to.present?
            uri = URI.parse(return_to)
            new_query = "party_id=#{@party.id}"
            uri.query = uri.query.present? ? "#{uri.query}&#{new_query}" : new_query
            redirect_to uri.to_s, notice: "Party created."
          else
            redirect_to teller_party_path(@party), notice: "Party created."
          end
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

    def accounts
      accounts = @party.accounts.includes(:branch).map do |account|
        {
          id: account.id,
          account_number: account.account_number,
          account_type: account.account_type,
          branch_code: account.branch&.code
        }
      end
      render json: accounts
    end

    private

      def set_party
        @party = Party.find(params[:id])
      end

      def ensure_authorized
        authorize([ :teller, @party || Party ], policy_class: Teller::PartyPolicy)
      end

      def party_params
        p = params.require(:party).permit(:party_kind, :relationship_kind, :display_name, :is_active, :tax_id, :street_address, :city, :state, :zip_code, :phone, :email)
        p[:state] = p[:state].to_s.upcase.presence
        p[:phone] = normalize_phone(p[:phone])
        p.delete(:tax_id) if @party&.persisted? && p[:tax_id].blank?
        p
      end

      def normalize_phone(phone)
        return nil if phone.blank?
        digits = phone.to_s.gsub(/\D/, "")
        return nil if digits.blank?
        main = digits[0, 10]
        ext = digits[10..]
        formatted = main.length == 10 ? main.gsub(/(\d{3})(\d{3})(\d{4})/, '\1-\2-\3') : main
        ext.present? ? "#{formatted} x#{ext}" : formatted
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
        p = params.require(:party).permit(:first_name, :last_name, :dob, :govt_id_type, :govt_id).slice(:first_name, :last_name, :dob, :govt_id_type, :govt_id).to_h.compact
        p.delete(:govt_id) if @party&.persisted? && p[:govt_id].blank?
        p
      end

      def organization_params
        params.require(:party).permit(:legal_name, :dba_name).slice(:legal_name, :dba_name).to_h.compact
      end

      def apply_parties_search(scope)
        if params[:q].present?
          q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)}%"
          scope = scope.where(
            "parties.display_name LIKE ? OR accounts.account_number LIKE ?",
            q, q
          )
        end
        scope = scope.where(tax_id: params[:tin].to_s.strip) if params[:tin].present?
        if params[:govt_id].present?
          scope = scope.where(party_individuals: { govt_id: params[:govt_id].to_s.strip })
        end
        scope
      end
  end
end
