# frozen_string_literal: true

require "test_helper"

module Teller
  module ReceiptsHelper
    class CheckHoldIndicatorTest < ActiveSupport::TestCase
      include Teller::ReceiptsHelper

      test "returns T for transit without hold" do
        assert_equal "T", check_hold_indicator({ "check_type" => "transit" })
        assert_equal "T", check_hold_indicator({ check_type: "transit" })
      end

      test "returns O for on_us without hold" do
        assert_equal "O", check_hold_indicator({ "check_type" => "on_us" })
        assert_equal "O", check_hold_indicator({ check_type: "on_us" })
      end

      test "returns T* for transit with hold" do
        assert_equal "T*", check_hold_indicator({ "check_type" => "transit", "hold_reason" => "large_item" })
      end

      test "returns O* for on_us with hold" do
        assert_equal "O*", check_hold_indicator({ "check_type" => "on_us", "hold_reason" => "new_account" })
      end

      test "defaults to T when check_type blank" do
        assert_equal "T", check_hold_indicator({})
        assert_equal "T", check_hold_indicator({ "check_type" => "" })
      end
    end
  end
end
