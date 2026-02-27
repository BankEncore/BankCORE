# frozen_string_literal: true

module Csr
  class AdvisoriesController < BaseController
    before_action :set_scope, only: [ :new, :create, :edit, :update ]
    before_action :set_advisory, only: [ :edit, :update ]
    before_action :ensure_authorized
    helper_method :filter_params, :advisory_edit_path

    def index
      load_advisories_with_filters
      @advisories = @advisories.includes(:created_by)
    end

    def new
      @scope_advisories_path = scope_advisories_path(filter_params.to_h.compact_blank)
      @advisory = Advisory.new(
        scope_type: @scope_type,
        scope_id: @scope_id,
        workspace_visibility: "csr",
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
        redirect_to scope_advisories_path_with_filters, notice: "Advisory created."
      else
        @scope_advisories_path = scope_advisories_path(filter_params.to_h.compact_blank)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @scope_advisories_path = scope_advisories_path(filter_params.to_h.compact_blank)
    end

    def update
      @advisory.updated_by_id = Current.user&.id

      if @advisory.update(advisory_params)
        redirect_to scope_advisories_path_with_filters, notice: "Advisory updated."
      else
        @scope_advisories_path = scope_advisories_path(filter_params.to_h.compact_blank)
        render :edit, status: :unprocessable_entity
      end
    end

    private

      def load_advisories_with_filters
        if params[:party_id].present?
          @scope_type = "party"
          @scope_id = params[:party_id]
          @scope_record = Party.find(@scope_id)
          @advisories = Advisory.for_scope(@scope_type, @scope_id).for_workspace("csr")
        elsif params[:account_id].present?
          @scope_type = "account"
          @scope_id = params[:account_id]
          @scope_record = Account.find(@scope_id)
          @advisories = Advisory.for_scope(@scope_type, @scope_id).for_workspace("csr")
        else
          @scope_type = nil
          @scope_id = nil
          @scope_record = nil
          @advisories = Advisory.for_workspace("csr")
          @advisories = @advisories.where(scope_type: params[:scope_type]) if params[:scope_type].in?(%w[party account])
        end

        @advisories = @advisories.ordered_for_display
        @advisories = @advisories.active if params[:active_only] != "false"
        @advisories = @advisories.where(category: params[:category]) if params[:category].present?
        @advisories = @advisories.where(severity: params[:severity]) if params[:severity].present?
        @advisories = @advisories.where(pinned: true) if params[:pinned] == "true"
        apply_date_filters
      end

      def apply_date_filters
        if (d = safe_parse_date(params[:created_from]))
          @advisories = @advisories.where("created_at >= ?", d)
        end
        if (d = safe_parse_date(params[:created_to]))
          @advisories = @advisories.where("created_at <= ?", d.end_of_day)
        end
        if (d = safe_parse_date(params[:starts_at]))
          @advisories = @advisories.where("effective_start_at IS NULL OR effective_start_at >= ?", d)
        end
        if (d = safe_parse_date(params[:ends_at]))
          @advisories = @advisories.where("effective_end_at IS NULL OR effective_end_at <= ?", d.end_of_day)
        end
      end

      def safe_parse_date(str)
        Date.parse(str.to_s) if str.present?
      rescue ArgumentError
        nil
      end

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

      def ensure_authorized
        authorize([ :csr, Advisory ], policy_class: Csr::AdvisoryPolicy)
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

      def scope_advisories_path(extra_params = {})
        opts = extra_params.to_h.compact_blank
        case @scope_type
        when "party" then csr_party_advisories_path(@scope_record, opts)
        when "account" then csr_account_advisories_path(@scope_record, opts)
        end
      end

      def scope_advisories_path_with_filters
        scope_advisories_path(filter_params.to_h.compact_blank)
      end

      def filter_params
        params.permit(:scope_type, :active_only, :category, :severity, :pinned, :created_from, :created_to, :starts_at, :ends_at)
      end

      def advisory_edit_path(advisory)
        scope_record = advisory.scope_record
        return nil unless scope_record.present?
        if advisory.scope_type == "party"
          edit_csr_party_advisory_path(scope_record, advisory)
        else
          edit_csr_account_advisory_path(scope_record, advisory)
        end
      end
  end
end
