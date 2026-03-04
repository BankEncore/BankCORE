# frozen_string_literal: true

module Teller
  module Parts
    class BaseController < Teller::BaseController
      include PostingPrerequisites
      include PartsPostingExecution

      before_action :ensure_authorized
      before_action :require_posting_context!
    end
  end
end
