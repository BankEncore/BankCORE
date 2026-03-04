# frozen_string_literal: true

module Teller
  module Parts
    class LandingController < Teller::BaseController
      include PostingPrerequisites

      before_action :require_posting_context!

      def index
        authorize([ :teller, :posting ], :create?)
      end
    end
  end
end
