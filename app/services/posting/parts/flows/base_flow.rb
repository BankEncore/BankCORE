# frozen_string_literal: true

module Posting
  module Parts
    module Flows
      class BaseFlow
        def validate!
          raise NotImplementedError, "#{self.class}#validate! must be implemented"
        end

        def build_entries
          raise NotImplementedError, "#{self.class}#build_entries must be implemented"
        end

        def valid?
          validate!
          true
        rescue Posting::Parts::PartBuilder::ValidationError
          false
        end
      end
    end
  end
end
