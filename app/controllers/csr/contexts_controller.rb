# frozen_string_literal: true

module Csr
  class ContextsController < ApplicationController
    layout "csr"

    def show
      authorize([ :csr, :dashboard ], :index?)

      @branches = Branch.order(:name)
    end

    def update
      authorize([ :csr, :dashboard ], :index?)

      branch = Branch.find_by(id: params[:branch_id])

      if branch.blank?
        redirect_to csr_context_path, alert: "Please select a valid branch."
        return
      end

      session[:current_branch_id] = branch.id
      cookies.permanent.signed[:current_branch_id] = { value: branch.id, httponly: true, same_site: :lax }

      redirect_to consume_csr_return_to(csr_root_path), notice: "Branch selected. Continue to CSR workspace."
    end

    private
      def consume_csr_return_to(default_path)
        session.delete(:csr_return_to).presence || default_path
      end
  end
end
