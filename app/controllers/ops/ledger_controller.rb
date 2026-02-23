module Ops
  class LedgerController < ApplicationController
    layout "ops"
    before_action :require_ops_access

    def index
      @ledger_legs = PostingLeg
        .includes(:posting_batch)
        .order('posting_batches.committed_at DESC, posting_legs.id ASC')
        .references(:posting_batch)
        .limit(100)
    end

    private
    def require_ops_access
      # TODO: Replace with real authorization logic
      true
    end
  end
end
