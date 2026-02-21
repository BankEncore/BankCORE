module Teller
  class PostingChecksController < ApplicationController
    include PostingPrerequisites

    before_action :ensure_authorized
    before_action :require_posting_context!

    def create
      render json: { ok: true, message: "Posting prerequisites satisfied" }
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end
  end
end
