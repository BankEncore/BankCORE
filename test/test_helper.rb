ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/ledger_reference_test_helper"

module ActiveSupport
  class TestCase
    include LedgerReferenceTestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup :ensure_ledger_references_for_fixtures

    # Add more helper methods to be used by all tests here...
  end
end
