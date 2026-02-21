module Teller
  class PostingsController < ApplicationController
    include PostingPrerequisites
    include TellerPostingExecution

    before_action :ensure_authorized
    before_action :require_posting_context!

    def create
      execute_posting
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end
  end
end
