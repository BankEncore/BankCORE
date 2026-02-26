# frozen_string_literal: true

module Teller
  class AdvisoriesController < BaseController
    before_action :set_scope, except: [ :for_entity, :acknowledge ]
    before_action :set_advisory, only: [ :edit, :update ]
    before_action :set_advisory_for_acknowledge, only: [ :acknowledge ]
    before_action :ensure_authorized
    skip_before_action :set_scope, only: [ :acknowledge ]
    def acknowledge
      return render json: { ok: false, error: "Advisory is not Severity 3" }, status: :unprocessable_entity unless @advisory.severity_requires_acknowledgment?

      ack = AdvisoryAcknowledgment.find_or_initialize_by(
        advisory: @advisory,
        user_id: Current.user&.id
      )
      ack.assign_attributes(
        workstation_id: Current.workstation&.id,
        teller_session_id: Current.teller_session&.id,
        acknowledged_at: Time.current
      )
      if ack.save
        render json: { ok: true, advisory_id: @advisory.id }
      else
        render json: { ok: false, error: ack.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    def for_entity
      scopes = resolve_entity_scopes
      if scopes.empty?
        render json: { ok: false, error: "scope_type and scope_id, party_id, account_id, or account_reference required" }, status: :unprocessable_entity
        return
      end

      advisory_ids = Set.new
      advisories = scopes.flat_map do |scope_type, scope_id|
        Advisory
          .for_scope(scope_type, scope_id)
          .for_workspace("teller")
          .active
          .ordered_for_display
          .limit(25)
          .reject { |a| advisory_ids.include?(a.id) }
          .each { |a| advisory_ids.add(a.id) }
      end
      advisories = advisories
        .sort_by { |a| [ a.pinned? ? 0 : 1, -(a.read_attribute_before_type_cast("severity") || 0), -(a.effective_start_at&.to_i || 0) ] }
        .first(50)
        .map { |a| advisory_json(a) }

      payload = { ok: true, advisories: advisories }
      if params[:account_reference].present?
        account = Account.find_by(account_number: params[:account_reference].to_s.strip)
        if account
          payload[:account_id] = account.id
          payload[:record_path] = Rails.application.routes.url_helpers.teller_account_path(account, tab: "advisories")
        end
      elsif params[:account_id].present?
        account = Account.find_by(id: params[:account_id])
        if account
          payload[:account_id] = account.id
          payload[:record_path] = Rails.application.routes.url_helpers.teller_account_path(account, tab: "advisories")
        end
      elsif params[:party_id].present?
        party = Party.find_by(id: params[:party_id])
        if party
          payload[:party_id] = party.id
          payload[:record_path] = Rails.application.routes.url_helpers.teller_party_path(party, tab: "advisories")
        end
      end

      render json: payload
    end

    def index
      @advisories = Advisory
        .for_scope(@scope_type, @scope_id)
        .for_workspace("teller")
        .ordered_for_display

      @advisories = @advisories.active if params[:active_only] != "false"
      @advisories = @advisories.includes(:created_by)
    end

    def new
      @scope_advisories_path = scope_advisories_path
      @advisory = Advisory.new(
        scope_type: @scope_type,
        scope_id: @scope_id,
        workspace_visibility: "teller",
        severity: :notice,
        pinned: false
      )
    end

    def create
      @advisory = Advisory.new(advisory_params)
      @advisory.scope_type = @scope_type
      @advisory.scope_id = @scope_id
      @advisory.created_by_id = Current.user&.id
      @advisory.updated_by_id = Current.user&.id

      if @advisory.save
        redirect_to scope_advisories_path, notice: "Advisory created."
      else
        @scope_advisories_path = scope_advisories_path
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @scope_advisories_path = scope_advisories_path
    end

    def update
      @advisory.updated_by_id = Current.user&.id

      if @advisory.update(advisory_params)
        redirect_to scope_advisories_path, notice: "Advisory updated."
      else
        @scope_advisories_path = scope_advisories_path
        render :edit, status: :unprocessable_entity
      end
    end

    private

      def set_scope
        if params[:party_id].present?
          @scope_type = "party"
          @scope_id = params[:party_id]
          @scope_record = Party.find(@scope_id)
        elsif params[:account_id].present?
          @scope_type = "account"
          @scope_id = params[:account_id]
          @scope_record = Account.find(@scope_id)
        else
          raise ActiveRecord::RecordNotFound
        end
      end

      def set_advisory
        @advisory = Advisory.for_scope(@scope_type, @scope_id).find(params[:id])
      end

      def set_advisory_for_acknowledge
        @advisory = Advisory.find(params[:id])
      end

      def ensure_authorized
        authorize([ :teller, Advisory ], policy_class: Teller::AdvisoryPolicy)
      end

      def advisory_params
        params.require(:advisory).permit(
          :category,
          :title,
          :body,
          :severity,
          :workspace_visibility,
          :effective_start_at,
          :effective_end_at,
          :pinned,
          :restriction_code
        )
      end

      def scope_advisories_path
        case @scope_type
        when "party" then teller_party_advisories_path(@scope_record)
        when "account" then teller_account_advisories_path(@scope_record)
        end
      end

      def resolve_entity_scopes
        if params[:party_id].present?
          [ [ "party", params[:party_id] ] ]
        elsif params[:account_id].present?
          account = Account.find_by(id: params[:account_id])
          scopes_for_account(account)
        elsif params[:account_reference].present?
          account = Account.find_by(account_number: params[:account_reference].to_s.strip)
          scopes_for_account(account)
        elsif params[:scope_type].present? && params[:scope_id].present?
          [ [ params[:scope_type], params[:scope_id] ] ]
        else
          []
        end
      end

      def scopes_for_account(account)
        return [] unless account.present?
        scopes = [ [ "account", account.id.to_s ] ]
        primary = account.primary_owner
        scopes << [ "party", primary.id.to_s ] if primary.present?
        scopes
      end

      def advisory_json(advisory)
        acknowledged = if Current.user.present?
          AdvisoryAcknowledgment
            .where(advisory: advisory, user: Current.user)
            .where("acknowledged_at >= ?", advisory.updated_at)
            .exists?
        else
          false
        end

        {
          id: advisory.id,
          scope_type: advisory.scope_type,
          scope_id: advisory.scope_id,
          category: advisory.category,
          title: advisory.title,
          body: advisory.body,
          severity: advisory.severity,
          pinned: advisory.pinned,
          effective_start_at: advisory.effective_start_at&.iso8601,
          effective_end_at: advisory.effective_end_at&.iso8601,
          acknowledged: acknowledged
        }
      end
  end
end
