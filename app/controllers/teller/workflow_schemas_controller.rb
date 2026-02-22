module Teller
  class WorkflowSchemasController < BaseController
    def show
      authorize([ :teller, :posting ], :create?)

      render json: {
        workflows: Teller::WorkflowRegistry.workflow_schema
      }
    end
  end
end
